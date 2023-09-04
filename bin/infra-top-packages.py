#!/usr/bin/python3

# sudo DEBIAN_FRONTEND=noninteractive apt-get update -y -qq -o Dpkg::Use-Pty=0 && sudo DEBIAN_FRONTEND=noninteractive apt-get install python3-apt -y -qq -o Dpkg::Use-Pty=0

import argparse, sys
import apt
import networkx as nx

# Command line arguments
parser = argparse.ArgumentParser(
    description = "Find top-level packages of the dependency graph"
)
parser.add_argument(
    "names", metavar = "package", nargs = "*",
    help = "package names to use (default: all installed packages)"
)
parser.add_argument(
    "--root-dir", metavar = "dir",
    help = "act as if chrooted in the specified directory"
)
parser.add_argument(
    "--follow-unspecified-packages", action = "store_true",
    help = "follow dependencies of packages not part of the initial input"
)
parser.add_argument(
    "--use-recommends", action = "store_false",
    help = "don't use recommended packages for the dependency graph"
)
parser.add_argument(
    "--show-missing-recommends", action = "store_true",
    help = "list missing recommended packages suffixed with a dash"
)

args = parser.parse_args()
cache = apt.Cache(rootdir = args.root_dir)

inputPackages = set()
providedPackages = dict()

# Convert package name to unique qualified package name (such as zlib1g:amd64)
def nameToPackage(name):
    if name not in cache:
        if name in providedPackages:
            return providedPackages[name]
        else:
            return None

    package = cache[name]
    if package.installed:
        return package.installed
    else:
        return max(package.versions)

def resolveDependencyBranch(dependency, arch):
    # Pick every possible or branch for simplicity if the dependency isn't one
    # of the input packages, which means we might not find all the root nodes,
    # but in practice usually isn't a problem since a branched dependency is
    # usually of libraries
    baseDependencies = set()
    for baseDependency in dependency.or_dependencies:
        package = nameToPackage(baseDependency.name + ":" + arch)
        if not package:
            continue

        if package in inputPackages:
            return {(package, type)}
        baseDependencies.add((package, baseDependency.rawtype))
    return baseDependencies

def outputPackageList(packages):
    if len(packages) > 1:
        return "(" + " ".join(packages) + ")"
    return packages[0]

# Find the packages
fail = False
for name in args.names:
    package = nameToPackage(name)
    if not package:
        print("Could not find in package cache:", name, file = sys.stderr)
        fail = True
        continue

    inputPackages.add(package)
    for name in package.provides:
        providedPackages[name + ":" + package.package.architecture()] = package
if fail:
    sys.exit(1)

# Use all installed packages if no packages were specified
if len(inputPackages) == 0:
    # Iterate over all packages known to apt (based on apt's on disk cache)
    for package in cache:
        package = package.installed

        # Ignore packages not installed
        if not package:
            continue

        inputPackages.add(package)
        for name in package.provides:
            providedPackages[name + ":" + package.package.architecture()] = package

# Build our dependency graph
packagesDG = nx.MultiDiGraph()
visitStack = list(inputPackages)
visitedPackages = set()
while len(visitStack) > 0:
    package = visitStack.pop()
    fullname = package.package.fullname
    packagesDG.add_node(fullname)
    visitedPackages.add(fullname)

    dependencies = package.dependencies
    if not args.use_recommends:
        dependencies.extend(package.recommends)

    arch = package.package.architecture()
    for dependency in dependencies:
        for dependencyPackage, type in resolveDependencyBranch(dependency, arch):
            dependencyFullname = dependencyPackage.package.fullname
            packagesDG.add_edge(fullname, dependencyFullname, type = type)

            if args.follow_unspecified_packages and dependencyFullname not in visitedPackages:
                visitStack.append(dependencyPackage)

# Remove any cycles
nodes = list(nx.strongly_connected_components(packagesDG))
packagesDAG = nx.condensation(packagesDG, scc = nodes)

# Find the nodes that have no in-edges - these are the top-level nodes
topLevelNodes = set()
for node in packagesDAG:
    if len(list(packagesDAG.predecessors(node))) == 0:
        topLevelNodes.add(node)

# Convert the nodes back into package names
topLevelPackages = set()
for node in topLevelNodes:
    packages = inputPackages & set(map(nameToPackage, nodes[node]))
    packages = sorted(package.package.name for package in packages)

    # The results should always be one of the input packages
    assert(len(packages) > 0)

    topLevelPackages.add(nameToPackage(packages[0]))
    print(packages[0])
#    if len(packages) > 1:
#        print("{} consists of {}".format(packages[0], outputPackageList(packages)), file = sys.stderr)

# Find missing recommend packages if requested
if args.show_missing_recommends:
    recommendedVias = dict()
    for edge in packagesDG.edges_iter(data = True):
        if edge[2]["type"] != "Recommends":
            continue
        package = nameToPackage(edge[1])
        if package and package not in inputPackages:
            recommendedVias.setdefault(edge[1], set()).add(edge[0])
    for edge in packagesDG.edges_iter(data = True):
        if edge[2]["type"] != "Recommends":
            recommendedVias.pop(edge[1], None)

    for name, via in recommendedVias.items():
        by = topLevelPackages & set(map(nameToPackage, nx.ancestors(packagesDG, name)))
        via = set(map(nameToPackage, via)) - set(by)

        name = nameToPackage(name).package.name
        via = sorted(package.package.name for package in via)
        by = sorted(package.package.name for package in by)

        print("{}-".format(name))
        print(
            "{}- is recommended by {}{}".format(
                name,
                outputPackageList(by),
                " via {}".format(outputPackageList(sorted(via))) if len(via) > 0 else ""
            ),
            file = sys.stderr
        )