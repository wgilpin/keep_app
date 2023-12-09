# keep_app

Implentation of the Doofer app in flutter

A clone of Google keep, with a chrome extension to capture HTML content and semantic search from an LLM

## Getting Started

Env vars: add the following to the file `testing.env` to allow you to press enter without typing all the details every time - ONLY when in dev mode locally:
```
TEST_EMAIL='default email'
TEST_PWD='default password'
```
## Chrome Extension

This is in the `/chromext` dir. There are two scripts here:
```
build-local.sh
build-prod.sh
```

### Build Local

The `build-local.sh` script builds a chrome extension to call a locally hosted server. The output will be 
in the folder `\chromext\build\local`

### Build Prod

The `build-prod.sh` script builds a chrome extension to call the remote prod server. The output will be 
in the file `\chromext\build\prod\build.zip` 

