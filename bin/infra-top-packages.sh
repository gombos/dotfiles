#!/usr/bin/env bash

# Find top-level packages of the dependency graph
# Plain bash (4.3+), no extra tools: package data comes from dpkg-query / apt-cache

set -euo pipefail
set -f
export LC_ALL=C

usage() {
    cat <<EOF
usage: ${0##*/} [-h] [--root-dir dir] [--follow-unspecified-packages]
       [--use-recommends] [--show-missing-recommends] [package ...]

Find top-level packages of the dependency graph

positional arguments:
  package                        package names to use (default: all installed packages)

options:
  -h, --help                     show this help message and exit
  --root-dir dir                 act as if chrooted in the specified directory
  --follow-unspecified-packages  follow dependencies of packages not part of the initial input
  --use-recommends               also use recommended packages for the dependency graph
  --show-missing-recommends      list missing recommended packages suffixed with a dash
EOF
}

# Command line arguments
names=()
rootDir=
follow=0
useRecommends=0
showMissing=0
while (( $# > 0 )); do
    case $1 in
        -h|--help) usage; exit 0 ;;
        --root-dir) (( $# > 1 )) || { usage >&2; exit 2; }; rootDir=$2; shift ;;
        --root-dir=*) rootDir=${1#*=} ;;
        --follow-unspecified-packages) follow=1 ;;
        --use-recommends) useRecommends=1 ;;
        --show-missing-recommends) showMissing=1; useRecommends=1 ;;
        --) shift; names+=("$@"); break ;;
        -*) echo "unrecognized argument: $1" >&2; usage >&2; exit 2 ;;
        *) names+=("$1") ;;
    esac
    shift
done

dpkgQuery=(dpkg-query)
aptCache=(apt-cache)
if [[ -n $rootDir ]]; then
    root=$(cd "$rootDir" && pwd)
    dpkgQuery+=("--admindir=$root/var/lib/dpkg")
    aptCache+=(-o "Dir=$root" -o "Dir::State::status=$root/var/lib/dpkg/status")
fi

# Per package (keyed by fullname = name:arch)
declare -A ARCH=() MULTIARCH=() DEPENDS=() RECOMMENDS=()
declare -A BYNAME=() PROVIDERS=()   # name -> space separated fullnames, in insertion order
declare -A INSTALLED=()

# Parse a relationship field into the RELATIONS array of or-groups "a:qual|b",
# ignoring version constraints, arch restrictions and build profiles
# (split first: pattern substitutions on long fields like rust Provides are very slow)
normalizeRelations() {
    local group groups alternative alternatives normalized IFS=,
    groups=($1)
    RELATIONS=()
    for group in "${groups[@]}"; do
        IFS='|'
        alternatives=($group)
        normalized=
        for alternative in "${alternatives[@]}"; do
            while true; do
                case $alternative in
                    *\(*\)*) alternative=${alternative%%\(*}${alternative#*\)} ;;
                    *\[*\]*) alternative=${alternative%%\[*}${alternative#*\]} ;;
                    *\<*\>*) alternative=${alternative%%\<*}${alternative#*\>} ;;
                    *) break ;;
                esac
            done
            alternative=${alternative//[[:space:]]/}
            [[ -z $alternative ]] || normalized+=${normalized:+|}$alternative
        done
        [[ -z $normalized ]] || RELATIONS+=("$normalized")
    done
}

nativeArch=

addPackage() { # record fields in rec_* variables
    local arch=${rec_Architecture:-$nativeArch}
    local fullname=$rec_Package:$arch
    [[ -n ${ARCH[$fullname]+x} ]] && return 1
    ARCH[$fullname]=$arch
    MULTIARCH[$fullname]=$rec_MultiArch
    DEPENDS[$fullname]=$rec_PreDepends,$rec_Depends
    RECOMMENDS[$fullname]=$rec_Recommends
    BYNAME[$rec_Package]+=" $fullname"

    if [[ -n $rec_Provides ]]; then
        local relation provided IFS='|'
        normalizeRelations "$rec_Provides"
        for relation in "${RELATIONS[@]}"; do
            for provided in $relation; do
                PROVIDERS[${provided%%:*}]+=" $fullname"
            done
        done
    fi
    REPLY=$fullname
    return 0
}

# Parse deb822 paragraphs (the format of dpkg's status file and apt-cache
# output) from stdin, calling $1 with the record in rec_* variables
parseRecords() {
    local callback=$1 line key value
    resetRecord() {
        rec_Package= rec_Architecture= rec_MultiArch= rec_Status=
        rec_PreDepends= rec_Depends= rec_Recommends= rec_Provides=
        key=
    }
    flushRecord() {
        [[ -n $rec_Package ]] && "$callback" || true
        resetRecord
    }
    resetRecord
    while IFS= read -r line || [[ -n $line ]]; do
        case $line in
            '')
                flushRecord ;;
            [[:space:]]*)
                if [[ -z ${line//[[:space:]]/} ]]; then
                    flushRecord
                elif [[ -n $key ]]; then
                    line=${line#"${line%%[![:space:]]*}"}
                    line=${line%"${line##*[![:space:]]}"}
                    printf -v "$key" '%s %s' "${!key}" "$line"
                fi ;;
            *:*)
                value=${line#*:}
                value=${value#"${value%%[![:space:]]*}"}
                value=${value%"${value##*[![:space:]]}"}
                case ${line%%:*} in
                    Package) key=rec_Package ;;
                    Architecture) key=rec_Architecture ;;
                    Multi-Arch) key=rec_MultiArch ;;
                    Status) key=rec_Status ;;
                    Pre-Depends) key=rec_PreDepends ;;
                    Depends) key=rec_Depends ;;
                    Recommends) key=rec_Recommends ;;
                    Provides) key=rec_Provides ;;
                    *) key= ;;
                esac
                [[ -n $key ]] && printf -v "$key" '%s' "$value" ;;
        esac
    done
    flushRecord
}

# Installed packages first, so they take precedence over available versions
fields=(Package Architecture Multi-Arch Status Pre-Depends Depends Recommends Provides)
installedFormat=
for field in "${fields[@]}"; do
    installedFormat+="$field: \${$field}\n"
done
installedFormat+='\n'
installedRecords=$("${dpkgQuery[@]}" -W -f "$installedFormat")

isInstalled() {
    [[ $rec_Status == installed || $rec_Status == *[[:space:]]installed ]]
}

# Native architecture of the (possibly chrooted) system is the one dpkg itself is built for
findNativeArch() {
    if [[ $rec_Package == dpkg && -z $nativeArch ]] && isInstalled; then
        nativeArch=$rec_Architecture
    fi
}
parseRecords findNativeArch <<< "$installedRecords"
[[ -n $nativeArch ]] || nativeArch=$(dpkg --print-architecture)

addInstalled() {
    if isInstalled && addPackage; then
        INSTALLED[$REPLY]=1
    fi
}
parseRecords addInstalled <<< "$installedRecords"
unset installedRecords

# Not-installed packages are only needed when the input or the graph can reach them
if (( ${#names[@]} > 0 || follow || showMissing )); then
    # Drop the fields we don't use up front, reading everything in bash is slow
    parseRecords addPackage < <(
        "${aptCache[@]}" dumpavail |
        grep -E '^($|Package:|Architecture:|Multi-Arch:|Pre-Depends:|Depends:|Recommends:|Provides:)' || true
    )
fi

# Pick the first candidate of the given architecture (or arch:all)
pickByArch() { # arch candidates...
    local arch=$1 fullname
    shift
    for fullname; do
        if [[ ${ARCH[$fullname]} == "$arch" || ${ARCH[$fullname]} == all ]]; then
            REPLY=$fullname
            return 0
        fi
    done
    return 1
}

# Resolve a dependency name to a package, the way a package of architecture
# `arch` would see it (real packages first, then providers of virtual ones).
# Result in REPLY, empty if nothing was found
declare -A RESOLVED=()
nameToPackage() { # name qualifier arch
    local name=$1 qualifier=$2 arch=$3 memo="$1 $2 $3" fullname IFS=' '
    if [[ -n ${RESOLVED[$memo]+x} ]]; then
        REPLY=${RESOLVED[$memo]}
        return
    fi

    if [[ $qualifier == native ]]; then
        arch=$nativeArch
    elif [[ -n $qualifier && $qualifier != any ]]; then
        arch=$qualifier
    fi

    local candidates=(${BYNAME[$name]-})
    REPLY=
    if ! pickByArch "$arch" "${candidates[@]}"; then
        for fullname in "${candidates[@]}"; do
            if [[ ${MULTIARCH[$fullname]} == foreign || ${MULTIARCH[$fullname]} == allowed ]]; then
                REPLY=$fullname
                break
            fi
        done
        if [[ -z $REPLY ]]; then
            candidates=(${PROVIDERS[$name]-})
            pickByArch "$arch" "${candidates[@]}" || REPLY=${candidates[0]-}
        fi
    fi
    RESOLVED[$memo]=$REPLY
}

declare -A INPUT=()

# Pick every possible or branch for simplicity if the dependency isn't one
# of the input packages, which means we might not find all the root nodes,
# but in practice usually isn't a problem since a branched dependency is
# usually of libraries. Result in the BRANCH array
resolveDependencyBranch() { # alternatives arch
    local alternative alternatives IFS='|'
    alternatives=($1)
    BRANCH=()
    for alternative in "${alternatives[@]}"; do
        [[ -n $alternative ]] || continue
        if [[ $alternative == *:* ]]; then
            nameToPackage "${alternative%%:*}" "${alternative#*:}" "$2"
        else
            nameToPackage "$alternative" "" "$2"
        fi
        [[ -n $REPLY ]] || continue

        if [[ -n ${INPUT[$REPLY]+x} ]]; then
            BRANCH=("$REPLY")
            return
        fi
        BRANCH+=("$REPLY")
    done
}

displayName() { # fullname
    local arch=${1##*:}
    if [[ $arch == "$nativeArch" || $arch == all ]]; then
        REPLY=${1%:*}
    else
        REPLY=$1
    fi
}

outputPackageList() { # packages...
    if (( $# > 1 )); then
        REPLY="($*)"
    else
        REPLY=${1-}
    fi
}

# Find the packages
fail=0
for name in "${names[@]}"; do
    if [[ $name == *:* ]]; then
        nameToPackage "${name%%:*}" "${name#*:}" "$nativeArch"
    else
        nameToPackage "$name" "" "$nativeArch"
    fi
    name=${name%%:*}
    if [[ -z $REPLY ]]; then
        echo "Could not find in package cache: $name" >&2
        fail=1
        continue
    fi
    INPUT[$REPLY]=1
done
(( fail == 0 )) || exit 1

# Use all installed packages if no packages were specified
if (( ${#INPUT[@]} == 0 )); then
    for fullname in "${!INSTALLED[@]}"; do
        INPUT[$fullname]=1
    done
fi

# Build our dependency graph: fullname -> space separated dependency fullnames,
# plus the typed edges (a pair can be linked by both Depends and Recommends)
declare -A SUCCESSORS=() EDGE=()
edges=()
visitStack=("${!INPUT[@]}")
while (( ${#visitStack[@]} > 0 )); do
    package=${visitStack[-1]}
    unset 'visitStack[-1]'
    [[ -z ${SUCCESSORS[$package]+x} ]] || continue
    SUCCESSORS[$package]=

    arch=${ARCH[$package]}
    [[ $arch != all ]] || arch=$nativeArch

    types=(Depends)
    (( useRecommends )) && types+=(Recommends)
    for type in "${types[@]}"; do
        if [[ $type == Depends ]]; then
            normalizeRelations "${DEPENDS[$package]}"
        else
            normalizeRelations "${RECOMMENDS[$package]}"
        fi
        for relation in "${RELATIONS[@]}"; do
            resolveDependencyBranch "$relation" "$arch"
            for dependency in "${BRANCH[@]}"; do
                if [[ -z ${EDGE["$package $dependency"]+x} ]]; then
                    EDGE["$package $dependency"]=1
                    SUCCESSORS[$package]+=" $dependency"
                fi
                if [[ -z ${EDGE["$package $dependency $type"]+x} ]]; then
                    EDGE["$package $dependency $type"]=1
                    edges+=("$package $dependency $type")
                fi

                if (( follow )) && [[ -z ${SUCCESSORS[$dependency]+x} ]]; then
                    visitStack+=("$dependency")
                fi
            done
        done
    done
done

# Dependencies that weren't followed are leaf nodes
for edge in "${edges[@]}"; do
    target=${edge#* } target=${target%% *}
    [[ -n ${SUCCESSORS[$target]+x} ]] || SUCCESSORS[$target]=
done

# Tarjan's algorithm (iterative, package graphs are too deep for recursion)
# Collapses cycles into single nodes: COMPONENT maps fullname -> node number,
# MEMBERS maps node number -> space separated fullnames
declare -A INDEX=() LOWLINK=() ONSTACK=() COMPONENT=()
MEMBERS=()
counter=0
stack=()
for start in "${!SUCCESSORS[@]}"; do
    [[ -z ${INDEX[$start]+x} ]] || continue
    INDEX[$start]=$counter LOWLINK[$start]=$counter
    (( ++counter ))
    stack+=("$start")
    ONSTACK[$start]=1
    work=("$start")
    position=(0)
    while (( ${#work[@]} > 0 )); do
        top=$(( ${#work[@]} - 1 ))
        node=${work[top]}
        children=(${SUCCESSORS[$node]})
        i=${position[top]}
        descended=0
        while (( i < ${#children[@]} )); do
            child=${children[i]}
            (( ++i ))
            if [[ -z ${INDEX[$child]+x} ]]; then
                position[top]=$i
                INDEX[$child]=$counter LOWLINK[$child]=$counter
                (( ++counter ))
                stack+=("$child")
                ONSTACK[$child]=1
                work+=("$child")
                position+=(0)
                descended=1
                break
            fi
            if [[ -n ${ONSTACK[$child]+x} ]] && (( INDEX[$child] < LOWLINK[$node] )); then
                LOWLINK[$node]=${INDEX[$child]}
            fi
        done
        (( descended )) && continue

        unset 'work[top]' 'position[top]'
        if (( top > 0 )); then
            parent=${work[top - 1]}
            if (( LOWLINK[$node] < LOWLINK[$parent] )); then
                LOWLINK[$parent]=${LOWLINK[$node]}
            fi
        fi
        if (( LOWLINK[$node] == INDEX[$node] )); then
            component=${#MEMBERS[@]}
            MEMBERS[component]=
            while true; do
                member=${stack[-1]}
                unset 'stack[-1]' "ONSTACK[$member]"
                COMPONENT[$member]=$component
                MEMBERS[component]+=" $member"
                [[ $member != "$node" ]] || break
            done
        fi
    done
done

# Find the nodes that have no in-edges - these are the top-level nodes
declare -A HASINEDGE=()
for source in "${!SUCCESSORS[@]}"; do
    for target in ${SUCCESSORS[$source]}; do
        if (( COMPONENT[$source] != COMPONENT[$target] )); then
            HASINEDGE[${COMPONENT[$target]}]=1
        fi
    done
done

# Convert the nodes back into package names, the input package sorting first
declare -A TOPLEVEL=()
topLevelNames=()
for (( node = 0; node < ${#MEMBERS[@]}; node++ )); do
    [[ -z ${HASINEDGE[$node]+x} ]] || continue
    best= bestName=
    for fullname in ${MEMBERS[node]}; do
        [[ -n ${INPUT[$fullname]+x} ]] || continue
        displayName "$fullname"
        if [[ -z $best || $REPLY < $bestName ]]; then
            best=$fullname bestName=$REPLY
        fi
    done

    # The results should always be one of the input packages
    if [[ -z $best ]]; then
        echo "assertion failed: top-level node without input packages:${MEMBERS[node]}" >&2
        exit 1
    fi

    TOPLEVEL[$best]=1
    topLevelNames+=("$bestName")
done

if (( ${#topLevelNames[@]} > 0 )); then
    printf '%s\n' "${topLevelNames[@]}" | sort
fi

# Find missing recommend packages if requested
if (( showMissing )); then
    declare -A RECOMMENDEDVIA=() PREDECESSORS=()
    for edge in "${edges[@]}"; do
        source=${edge%% *} type=${edge##* } target=${edge#* } target=${target%% *}
        if [[ $type == Recommends && -z ${INPUT[$target]+x} ]]; then
            RECOMMENDEDVIA[$target]+=" $source"
        fi
        PREDECESSORS[$target]+=" $source"
    done
    for edge in "${edges[@]}"; do
        type=${edge##* } target=${edge#* } target=${target%% *}
        [[ $type == Recommends ]] || unset "RECOMMENDEDVIA[$target]"
    done

    # Sort by display name
    sorted=()
    for fullname in "${!RECOMMENDEDVIA[@]}"; do
        displayName "$fullname"
        sorted+=("$REPLY $fullname")
    done
    if (( ${#sorted[@]} > 0 )); then
        mapfile -t sorted < <(printf '%s\n' "${sorted[@]}" | sort)
    fi

    for entry in "${sorted[@]}"; do
        name=${entry%% *} fullname=${entry#* }

        # Top-level packages among the ancestors
        unset FOUND
        declare -A FOUND=()
        visitStack=("$fullname")
        while (( ${#visitStack[@]} > 0 )); do
            current=${visitStack[-1]}
            unset 'visitStack[-1]'
            for predecessor in ${PREDECESSORS[$current]-}; do
                if [[ -z ${FOUND[$predecessor]+x} ]]; then
                    FOUND[$predecessor]=1
                    visitStack+=("$predecessor")
                fi
            done
        done
        by=()
        for ancestor in "${!FOUND[@]}"; do
            if [[ -n ${TOPLEVEL[$ancestor]+x} ]]; then
                displayName "$ancestor"
                by+=("$REPLY")
            fi
        done

        via=()
        for recommender in ${RECOMMENDEDVIA[$fullname]}; do
            [[ -z ${TOPLEVEL[$recommender]+x} || -z ${FOUND[$recommender]+x} ]] || continue
            displayName "$recommender"
            via+=("$REPLY")
        done

        (( ${#by[@]} == 0 )) || mapfile -t by < <(printf '%s\n' "${by[@]}" | sort -u)
        (( ${#via[@]} == 0 )) || mapfile -t via < <(printf '%s\n' "${via[@]}" | sort -u)

        echo "$name-"
        outputPackageList "${by[@]}"
        message="$name- is recommended by $REPLY"
        if (( ${#via[@]} > 0 )); then
            outputPackageList "${via[@]}"
            message+=" via $REPLY"
        fi
        echo "$message" >&2
    done
fi
