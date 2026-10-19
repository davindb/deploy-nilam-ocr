# deploy-ocr

Deploy NILAM OCR ke GKE dari image yang sudah ada di Nexus BRI. Repo ini **tidak membangun image**;
image di-push dari repo aplikasinya (`nilam-ocr-orchestration/deploy/push-nexus.sh`) ke
`new-nexus.gcp.bri.co.id/bribrain/<dev|prd>/nilam/<project>/<image>:<git-sha>`.

| Komponen | Chart | Script | Image Nexus |
|---|---|---|---|
| OCR backend: api + worker (satu image) | `charts/ocr-backend` | `scripts/deploy-ocr-backend.sh` | `ms-bribrain-nilam-ocr-orchestrator` |
| RBAC admin UI | `charts/ocr-rbac-ui` | `scripts/deploy-rbac-ui.sh` | `ms-bribrain-nilam-ocr-rbac-ui` |

## Struktur

```
charts/<chart>/            chart generik, tanpa nilai khusus environment
environments/<env>.env     target GKE + path Nexus + nama release (tanpa rahasia, di-commit)
environments/<env>/*.yaml  override values per chart untuk environment itu
scripts/                   _lib.sh (dipakai bersama) + satu script deploy per komponen
.env                       rahasia lokal (akun Nexus), tidak di-commit
```

Urutan prioritas nilai: **env shell > `.env` > `environments/<env>.env`**. Values helm: `charts/<chart>/values.yaml`
→ `environments/<env>/<chart>.yaml` → `--set` dari script → argumen setelah `--`.

## Prasyarat

- `gcloud` (sudah `gcloud auth login`), `gke-gcloud-auth-plugin`, `kubectl`, `helm` 3.13+ atau 4, `docker`
- `docker login new-nexus.gcp.bri.co.id` di mesin ini, dan VPN kantor aktif (script mengecek tag ada di Nexus
  sebelum deploy)
- Cluster bisa menjangkau `new-nexus.gcp.bri.co.id` dan punya metrics-server (untuk HPA)

## Sekali di awal

```bash
cp .env.example .env    # isi NEXUS_USERNAME / NEXUS_PASSWORD (akun service, bukan akun pribadi)
```

Script membuat/memperbarui Secret pull `nexus-pull-secret` dari akun itu setiap deploy.

**Secret aplikasi** `ocr-orchestration` (dibaca api dan worker lewat `envFrom`) dibuat manual, tidak lewat chart,
supaya rahasia tidak pernah masuk values. Isinya `.env` aplikasi dengan alamat versi cluster; resep lengkapnya di
`nilam-ocr-orchestration/deploy/README.md` bagian "Install pertama kali":

```bash
kubectl create secret generic ocr-orchestration -n <namespace> --from-env-file=/tmp/ocr.env
```

URL di Secret itu (`REDIS_URL`, `OCR_<TYPE>_SERVICE_URL`, `DATAHUB_SERVICE_URL`) pakai FQDN
`<service>.<namespace>.svc.cluster.local` bila servisnya ada di namespace lain.

## Deploy

```bash
./scripts/deploy-ocr-backend.sh ec05d54     # api + worker
./scripts/deploy-rbac-ui.sh d25f1de         # admin UI
```

Tag wajib dan harus git short sha yang sudah di-push; tidak ada tag default seperti `dev`/`latest`, karena tag
yang berpindah tidak bisa di-rollback dan bisa diam-diam menjalankan image lama.

Yang dilakukan script: cek tag ada di Nexus → `get-credentials` → buat namespace bila belum ada → perbarui Secret
pull → cek Secret aplikasi → cek tidak ada objek milik release lain → `helm upgrade --install --wait` dengan
rollback otomatis bila gagal (`--rollback-on-failure` di Helm 4, `--atomic` di Helm 3).

```bash
./scripts/deploy-ocr-backend.sh ec05d54 --dry-run                     # render manifest saja, tanpa cluster
./scripts/deploy-ocr-backend.sh ec05d54 -- --set autoscaling.worker.maxReplicas=8
helm rollback ocr-backend -n ocr-dev                                  # atau deploy ulang tag lama
```

## Ganti project, cluster, atau namespace

Sekali jalan, dari shell:

```bash
GKE_PROJECT=project-lain GKE_CLUSTER=cluster-lain NAMESPACE=ocr-test ./scripts/deploy-ocr-backend.sh ec05d54
```

Permanen: ubah `environments/dev.env`. Environment baru (mis. `prd`): salin `environments/dev.env` ke
`environments/prd.env` dan folder `environments/dev/` ke `environments/prd/`, ganti nilainya (termasuk
`NEXUS_PATH=bribrain/prd/...`), lalu `./scripts/deploy-ocr-backend.sh <tag> --env prd`.

## Autoscaling (HPA)

HPA aktif untuk api, worker, dan admin UI (`autoscaling.*` di values chart). Selama HPA aktif, Deployment tidak
menulis `replicas`, supaya `helm upgrade` tidak mereset jumlah pod yang dipilih HPA. Target CPU dihitung dari
`resources.requests`, jadi request harus realistis. Scale-down dibatasi satu pod per menit, dengan jeda
stabilisasi 5 menit (api, UI) dan 10 menit (worker).

## Worker

- Image dan Secret sama dengan api; perintahnya `arq src.workers.ocr_worker.WorkerSettings`.
- `terminationGracePeriodSeconds: 120`: job OCR butuh puluhan detik; default 30 detik memotongnya saat rollout.
- Liveness `arq --check`: membaca health-check key worker di Redis, jadi pod direstart bila worker berhenti
  heartbeat atau Redis tidak terjangkau. Interval heartbeat arq default 1 jam; set `worker.livenessProbe: {}`
  untuk mematikan.
- Tanpa Service dan tanpa readiness probe: worker tidak melayani trafik.
- HPA CPU hanya jaring pengaman: worker kebanyakan menunggu HTTP ke layanan OCR, jadi antrean bisa menumpuk
  saat CPU rendah. Antrean arq berupa sorted set, sehingga scaler Redis list KEDA tidak bisa membacanya;
  scaling berdasarkan panjang antrean butuh metrik custom.
- PodDisruptionBudget `maxUnavailable: 1` (bukan `minAvailable: 1`, yang memblokir drain node bila replika 1).

## Migrasi dari chart lama

Chart lama (`nilam-ocr-orchestration/deploy`, release `ocr-dev` di namespace `ocr-dev`) membuat objek dengan
nama yang sama (`ocr-orchestration`, `ocr-orchestration-api`, `-worker`, `ocr-admin-ui`) tetapi label selector
berbeda. Helm menolak mengambil alih objek milik release lain, dan script berhenti lebih awal dengan pesan yang
menyebut objeknya.

1. **Disarankan: berdampingan di namespace baru.** `NAMESPACE=<baru>`, salin Secret `ocr-orchestration` (ganti
   URL nama pendek ke FQDN namespace lama), deploy, uji, lalu pindahkan konsumen ke IP LoadBalancer baru dan
   hapus Deployment/Service lama. Tanpa downtime.
2. **Namespace yang sama.** Hapus dulu Deployment, Service, dan HPA lama milik release `ocr-dev` (bukan
   `helm uninstall ocr-dev`, yang juga menghapus MinIO). Ada downtime, dan IP LoadBalancer berubah kecuali
   memakai IP statis (`service.loadBalancerIP`).

## Standar untuk servis berikutnya

- Satu chart per komponen yang di-deploy terpisah; api dan worker yang berbagi image tetap satu chart.
- Label `app.kubernetes.io/{name,instance,component,version,part-of}`; selector hanya name, instance, component.
- Image dari Nexus dengan tag sha yang immutable dan `pullPolicy: IfNotPresent`.
- Rahasia di Secret yang dibuat di luar chart (`existingSecret`), tidak pernah di values.
- Readiness memeriksa dependensi; liveness hanya proses itu sendiri, supaya gangguan database tidak memicu
  restart massal.
- Tanpa CPU limit (throttling merusak latensi), memory limit tetap ada; HPA tanpa `replicas` di Deployment;
  PDB `maxUnavailable`.
- `runAsNonRoot` dengan UID numerik, `seccompProfile: RuntimeDefault`, drop semua capability,
  `automountServiceAccountToken: false`.
- Script: tag wajib, cek image sebelum deploy, `--wait` dengan rollback otomatis, `--dry-run` tanpa cluster.

Validasi lokal: `helm lint charts/<chart> -f environments/dev/<chart>.yaml --strict` dan
`./scripts/deploy-<x>.sh <tag> --dry-run | kubeconform -strict -summary`.
