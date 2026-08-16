#!/usr/bin/env bash

./generate_ci.sh >.github/workflows/build.yml


export GRPC_REQUEST_SCENARIO=${GRPC_REQUEST_SCENARIO:-"complex_proto"}
export GRPC_IMAGE_NAME="${GRPC_IMAGE_NAME:-grpc_bench}"
export GRPC_RUST_VERSION="${GRPC_RUST_VERSION:-1.97}"
export GRPC_GO_VERSION=${GRPC_GO_VERSION:-"1.26.2-bookworm"}

## The list of benchmarks to build
BENCHMARKS_TO_BUILD="${@}"
##  ...or use all the *_bench dirs by default
BENCHMARKS_TO_BUILD="${BENCHMARKS_TO_BUILD:-$(find . -maxdepth 1 -name '*_bench' -type d | sort)}"


# Function to build precached image for a language
build_precached_image() {
    local language="$1"
    local dockerfile="docker_stages/Dockerfile.${language}"
    local tag="${GRPC_IMAGE_NAME}:precached_${language}"
    
    # Check if dockerfile exists
    if [[ ! -f "${dockerfile}" ]]; then
        echo "Warning: ${dockerfile} not found, skipping precached build for ${language}"
        return 1
    fi
    
    echo "==> Building precached image for ${language}..."
    (
        DOCKER_BUILDKIT=1 docker image build \
            --force-rm \
            --pull \
            --compress \
            --file "${dockerfile}" \
            --tag "${tag}" \
            . >"${language}_precached.tmp" 2>&1 &&
            rm -f "${language}_precached.tmp" &&
            echo "==> Done building precached ${language}" &&
            return 0
    ) || (
        cat "${language}_precached.tmp"
        rm -f "${language}_precached.tmp"
        echo "==> Error building precached ${language}"
        return 1
    )
}

# Function to check if any benchmark for a language needs precached image
needs_precached() {
    local lang_prefix="$1"
    for benchmark in ${BENCHMARKS_TO_BUILD}; do
        benchmark=${benchmark##*/}
        if [[ "${benchmark}" == ${lang_prefix}_* ]]; then
            return 0
        fi
    done
    return 1
}

# Build precached images for languages that have benchmarks
precached_builds=""
languages_to_precache=()

# Check for Rust benchmarks
if needs_precached "rust"; then
    languages_to_precache+=("rust")
fi

# Check for Go benchmarks
if needs_precached "go"; then
    languages_to_precache+=("go")
fi

# Build all required precached images in parallel
for lang in "${languages_to_precache[@]}"; do
    build_precached_image "${lang}" &
    precached_builds="${precached_builds} ${!}"
done

echo "Waiting for precached builds to finish..."
for job in ${precached_builds}; do
    if ! wait "${job}"; then
        echo "Error building precached image(s)"
        exit 1
    fi
done
echo "All precached builds finished successfully"

# Setup the chosen scenario
if ! sh setup_scenario.sh $GRPC_REQUEST_SCENARIO false; then
	echo "Scenario setup fiascoed."
	exit 1
fi

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

builds=""
for benchmark in ${BENCHMARKS_TO_BUILD}; do
	benchmark=${benchmark##*/}

	echo "==> Building Docker image for ${benchmark}..."
	( (
		DOCKER_BUILDKIT=1 docker image build \
			--force-rm \
			--pull \
			--compress \
			--build-arg RUST_VERSION="$GRPC_RUST_VERSION" \
            --build-arg GO_VERSION="$GRPC_GO_VERSION" \
			--file "${benchmark}/Dockerfile" \
			--tag "$GRPC_IMAGE_NAME:${benchmark}-$GRPC_REQUEST_SCENARIO" \
			. >"${benchmark}.tmp" 2>&1 &&
			rm -f "${benchmark}.tmp" &&
			echo "==> Done building ${benchmark}"
	) || (
		cat "${benchmark}.tmp"
		rm -f "${benchmark}.tmp"
		echo "==> Error building ${benchmark}"
		exit 1
	) ) &
	builds="${builds} ${!}"
done

echo "==> Waiting for the builds to finish..."
for job in ${builds}; do
	if ! wait "${job}"; then
		wait
		echo "Error building Docker image(s)"
		exit 1
	fi
done
echo "All done."
