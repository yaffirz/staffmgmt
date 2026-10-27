FROM node:20-alpine

# git is needed to install nodeafis straight from GitHub.
RUN apk add --no-cache git

WORKDIR /app
COPY package.json ./
# nodeafis ships TypeScript source only (no prebuilt dist and no prepare script),
# so install it, then build it with its OWN pinned toolchain (typescript 5.6 etc.)
# into node_modules/nodeafis/dist.
RUN npm install \
 && ( cd node_modules/nodeafis && npm install && npm run build ) \
 && npm cache clean --force
COPY server.js ./

ENV PORT=9000
EXPOSE 9000
CMD ["node", "server.js"]
