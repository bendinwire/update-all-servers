# docker.zsh
# Docker update functions:
#   update_docker_host

#!/bin/zsh

update_docker_host() {
  # Expand DOCKER_COMPOSE_DIRS locally so the remote script gets the real paths.
  # DOCKER_COMPOSE_DIRS is defined in config.zsh.
  local dirs
  dirs="${(j: :)DOCKER_COMPOSE_DIRS}"

cat <<EOF

echo "Checking Docker Compose stacks..."

for ROOT in $dirs
do
    [ ! -d "\$ROOT" ] && continue

    find "\$ROOT" -type f \
      \( -name docker-compose.yml -o \
         -name docker-compose.yaml -o \
         -name compose.yml -o \
         -name compose.yaml \) 2>/dev/null |

    while read FILE
    do
        DIR=\$(dirname "\$FILE")

        cd "\$DIR" || continue
        docker compose version >/dev/null 2>&1 || continue

        # Only update stacks that are ALREADY running. Don't start dormant or
        # alternate stacks we happen to find on disk — e.g. a source repo's
        # bundled compose file for a service that actually runs natively
        # (PoolPi's nodejs-poolController vs. the native njsPC on :4200).
        if [ -z "\$(docker compose ps -q 2>/dev/null)" ]; then
            echo "⏭️  Skipping \$DIR (no running containers)"
            continue
        fi

        echo ""
        echo "🐳 Updating: \$DIR"
        docker compose pull
        docker compose up -d --remove-orphans

        echo ""
        docker compose ps
    done
done

docker image prune -af || true

echo ""
docker system df

EOF
}
