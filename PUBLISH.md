# Publishing the chunked build

Run these from a Git Bash / terminal (the GitHub CLI is already logged in as `malachai-build`).
The loader and README assume the repo name `matcha-bloxfruits`; if you pick another name,
edit `BASE` in `loader.lua` and the URLs in `README.md` first.

## 1. Initialise the repo and commit

```bash
cd "/d/matcha laods/Blox Fruits" && cp /d/test.CHANGES.md CHANGES.md && git init -b main && git add loader.lua src dist/test.full.lua README.md CHANGES.md build.sh check.sh .gitignore test.txt && git commit -m "Chunked loadstring build of the Matcha Blox Fruits script"
```

## 2. Create the public repo and push

Raw GitHub URLs only serve public repos, which is what `loadstring(game:HttpGet(...))` needs.

```bash
cd "/d/matcha laods/Blox Fruits" && gh repo create matcha-bloxfruits --public --source . --remote origin --push
```

## 3. Check the raw files are being served (can take a minute after the push)

```bash
curl -sI https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/loader.lua | head -1
```

## 4. The one-line loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/loader.lua"))()
```

Matcha's global `httpget` works too:

```lua
loadstring(httpget("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/loader.lua"))()
```

Single-chunk fallback:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/dist/test.full.lua"))()
```

## Updating later

Edit the chunk in `src/`, then:

```bash
cd "/d/matcha laods/Blox Fruits" && bash check.sh && git add -A && git commit -m "update" && git push
```

Raw URLs are cached by GitHub for a few minutes after a push.
