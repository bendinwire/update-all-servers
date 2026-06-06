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

        echo ""
        echo "🐳 Updating: \$DIR"

        cd "\$DIR" || continue

        if docker compose version >/dev/null 2>&1; then
            docker compose pull
            docker compose up -d --remove-orphans

            echo ""
            docker compose ps
        fi
    done
done

docker image prune -af || true

echo ""
docker system df

EOF
}
