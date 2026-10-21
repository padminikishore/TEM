# --- STAGE 1: DEPENDENCY INSTALLATION ---
FROM node:20-alpine AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci

# --- STAGE 2: APPLICATION BUILDER ---
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Generate the Prisma database client bindings
RUN npx prisma generate
# Compile Next.js production builds & Tailwind styles
RUN npm run build

# --- STAGE 3: RUNTIME RUNNER ---
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1002 nextjs

# Copy only the compiled production chunks and assets
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma

USER nextjs
EXPOSE 3000
ENV PORT=3000
HOST 0.0.0.0

CMD ["node", "server.js"]
