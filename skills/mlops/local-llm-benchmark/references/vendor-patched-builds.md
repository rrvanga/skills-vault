# Running Vendor-Patched llama.cpp Arch Builds

When a GGUF fails to load with `unknown model architecture: '<arch>'`, the GGUF is usually NOT broken — the arch is simply newer than (or not in) your llama.cpp build. This is common for vendor "hybrid"/probe/edge variants of a base model (e.g. `gemma-4-e2b-it-hybrid`), which ship their own llama.cpp patch series. There is a reliable build path.

## 1. Confirm you're on the latest release first

```bash
curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['tag_name'], d['published_at'])"
# your build version:
/tmp/llama-*/llama-server --version
```

If you ARE on latest and it still says unknown arch, the arch is beyond (or parallel to) upstream → proceed to vendor patch. This closed the "just update llama.cpp" answer.

## 2. Find the vendor's patch repo (NOT the GGUF repo)

The GGUF repo's README may reference a `patches/llama.cpp/install.sh` path that **404s** in that HF repo — the real patches live in the vendor's **GitHub org**, not on HF. Find the org's repos and grep them for the arch name:

```bash
curl -s "https://api.github.com/orgs/<VENDOR>/repos?per_page=50" \
  | python3 -c "import sys,json;[print(r['full_name'],'|',(r.get('description') or '')[:60]) for r in json.load(sys.stdin)]"
# Look for a repo matching the model/hybrid name. Session example:
#   cactus-compute/cactus-hybrid  ->  "On-device models that know when they're wrong"
#   that repo's tree had:  patches/llama.cpp/{PIN, apply.sh, install.sh, README.md} + patches/*.patch
```

Confirm the patch files exist via the GitHub trees API:
```bash
curl -s "https://api.github.com/repos/<VENDOR>/<patchrepo>/git/trees/main?recursive=1" \
  | python3 -c "import sys,json; [print(e['path']) for e in json.load(sys.stdin)['tree'] if 'patch' in e['path'].lower() or 'llama' in e['path'].lower()]"
```

## 3. Apply the vendor patch series to a pinned llama.cpp tag

Vendor repos ship `PIN` (a tag), `apply.sh`, `install.sh`. The essence (works regardless of their helpers):

```bash
git clone --depth 1 --branch "$(cat PIN)" https://github.com/ggml-org/llama.cpp.git llama-src
cd llama-src && git checkout -b vendor-hybrid
git -c user.name=build -c user.email=build@localhost am ../patches/*.patch   # 1 commit per patch
# verify all applied & arch now known:
git log --oneline | head -8                 # should show one commit per patch
grep -rl "<arch-name>" gguf-py/gguf/constants.py
ls .git/rebase-apply 2>/dev/null || echo "no am in progress (all applied)"
```

If a patch did NOT apply (fewer commits than patches, or `git am` stopped), apply the missing `.patch` file individually with a second `git am`.

Then build just the server (skip the optional test target to save time/space):
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TESTS=OFF
cmake --build build -j "$(nproc)" --target llama-server llama-cli
```

## 4. Authoritative verification = a real server load

The first `llama-server -m model.gguf` run IS the load test — watch the log for `load_model:` accepting the arch. `/v1/models` naming the new model is secondary confirmation. A plain `--dry-run`/parse is not a substitute for an actual load.

## Gotchas learned

- **The vendor PIN tag may be OLDER than your current build** — that's fine; the vendor tested against it. Don't force your newer upstream build onto the patches; use the pinned tag.
- **Patch count check**: `install.sh` builds a `test-gemma-<arch>-probe` target; if you build with `LLAMA_BUILD_TESTS=OFF` you can skip needing the golden-test patch (it's only for `ctest`), but applying it anyway keeps the tree faithful to the vendor.
- **Arch vs probe tensors**: a plain shared-arch model loads fine on upstream; a vendor-hybrid arch fails with unknown-architecture until patched. The failure means "arch not registered," not "bad weights."
- **The stale-server port trap**: after killing a model, the old server may still hold :8080; the new server exits silently and `/v1/models` reports the OLD model. `ss -tlnp | grep 8080` and kill before relaunching, then confirm the new name.
- Requires `cmake` (`pacman -S cmake` on Arch). /tmp is tmpfs — a full llama.cpp clone (~600MB) + build (few hundred MB) plus the 2–4GB model must fit; free already-benchmarked model files first (`df -h /tmp`).
