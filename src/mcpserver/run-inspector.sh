npm install

npx tsc --project tsconfig.json --outDir dist

npm ci

npx @modelcontextprotocol/inspector node dist/index.js