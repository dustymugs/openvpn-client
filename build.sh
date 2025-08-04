#!/bin/bash

set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

cd $SCRIPTDIR

DOCKER_REGISTRIES=()
while getopts ":i:t:r:dc" opt; do
	case "${opt}" in
		i)
			IMAGE_TAG=${OPTARG}
			;;
		r)
			DOCKER_REGISTRIES[${#DOCKER_REGISTRIES[@]}]=${OPTARG}
			;;
		d)
			DEPLOY_ONLY=1
			;;
		c)
			NO_CACHE="--no-cache"
			;;
		:)
			echo "Usage: $0 -i IMAGE_TAG [-r ECR_URI] [-d]" >&2
			exit 1
			;;
	esac
done
shift $((OPTIND - 1))

USER="ezee"

#
# image
#

if [ -z "$IMAGE_TAG" ]; then
	IMAGE_TAG="latest"
fi

IMAGE_ROOT="openvpn-client"
REMOTE_IMAGE_ROOT="openvpn-client"
DOCKERFILE="Dockerfile"

BASE_IMAGE="dustymugs/${IMAGE_ROOT}:$IMAGE_TAG"
if [ -z "$DEPLOY_ONLY" ]; then
	echo
	echo "Building image: ${BASE_IMAGE}"
	docker build ${NO_CACHE} --rm -f ${DOCKERFILE} -t "$BASE_IMAGE" .
fi

#
# push to registry
#

if [ ${#DOCKER_REGISTRIES[@]} -lt 1 ]; then
	echo "No Docker Registry set. All done!"
	exit 0
fi

for registry in "${DOCKER_REGISTRIES[@]}"; do
	REMOTE_BASE_IMAGE="${registry}/${REMOTE_IMAGE_ROOT}:${IMAGE_TAG}"
	echo
	echo "Tagging remote image: \"${BASE_IMAGE}\" => \"${REMOTE_BASE_IMAGE}\""
	docker tag "${BASE_IMAGE}" "${REMOTE_BASE_IMAGE}"

	echo
	echo "Pushing remote image: \"${REMOTE_BASE_IMAGE}\""
	docker push "${REMOTE_BASE_IMAGE}"

	echo
	echo "Docker images pushed to Docker Registry: ${registry}"
done

echo
echo "All done!"
