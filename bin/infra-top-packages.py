#!/usr/bin/env python3

# Plain python3, no extra modules: package data comes from dpkg-query / apt-cache

import argparse, os, re, subprocess, sys

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
    "--use-recommends", action = "store_true",
    help = "also use recommended packages for the dependency graph"
)
parser.add_argument(
    "--show-missing-recommends", action = "store_true",
    help = "list missing recommended packages suffixed with a dash"
)

args = parser.parse_args()
if args.show_missing_recommends:
    args.use_recommends = True

dpkgQuery = ["dpkg-query"]
aptCache = ["apt-cache"]
if args.root_dir:
    root = os.path.abspath(args.root_dir)
    dpkgQuery.append("--admindir=" + os.path.join(root, "var/lib/dpkg"))
    aptCache += [
        "-o", "Dir=" + root,
        "-o", "Dir::State::status=" + os.path.join(root, "var/lib/dpkg/status"),
    ]

def run(command):
    return subprocess.run(command, check = True, capture_output = True, text = True).stdout

# Parse deb822 paragraphs (the format of dpkg's status file and apt-cache output)
def parseRecords(text):
    for paragraph in re.split(r"\n\s*\n", text):
        record = {}
        key = None
        for line in paragraph.splitlines():
            if line[:1] in (" ", "\t"):
                if key:
                    record[key] += " " + line.strip()
            elif ":" in line:
                key, _, value = line.partition(":")
                record[key] = value.strip()
        if record.get("Package"):
            yield record

# Parse a relationship field into a list of or-groups of (name, arch qualifier),
# ignoring version constraints, arch restrictions and build profiles
def parseRelations(field):
    relations = []
    for group in field.split(","):
        alternatives = []
        for alternative in group.split("|"):
            alternative = re.sub(r"\(.*?\)|\[.*?\]|<.*?>", "", alternative).strip()
            if alternative:
                name, _, qualifier = alternative.partition(":")
                alternatives.append((name, qualifier))
        if alternatives:
            relations.append(alternatives)
    return relations

class Package:
    def __init__(self, record):
        self.name = record["Package"]
        self.arch = record.get("Architecture") or nativeArch
        self.multiArch = record.get("Multi-Arch", "")
        self.fullname = self.name + ":" + self.arch
        self.depends = (
            parseRelations(record.get("Pre-Depends", "")) +
            parseRelations(record.get("Depends", ""))
        )
        self.recommends = parseRelations(record.get("Recommends", ""))
        self.provides = [name for group in parseRelations(record.get("Provides", "")) for name, _ in group]

    # Architecture used to resolve this package's dependencies
    @property
    def dependencyArch(self):
        return nativeArch if self.arch == "all" else self.arch

    # Name as apt shows it: qualified only for foreign architectures
    @property
    def displayName(self):
        return self.name if self.arch in (nativeArch, "all") else self.fullname

byName = dict()
byFullname = dict()
providers = dict()

def addPackage(package):
    if package.fullname in byFullname:
        return
    byFullname[package.fullname] = package
    byName.setdefault(package.name, []).append(package)
    for name in package.provides:
        providers.setdefault(name, []).append(package)

# Installed packages first, so they take precedence over available versions
installedFormat = "".join(
    "{0}: ${{{0}}}\n".format(field)
    for field in ["Package", "Architecture", "Multi-Arch", "Status", "Pre-Depends", "Depends", "Recommends", "Provides"]
) + "\n"
installedRecords = [
    record for record in parseRecords(run(dpkgQuery + ["-W", "-f", installedFormat]))
    if record.get("Status", "").split()[-1:] == ["installed"]
]

# Native architecture of the (possibly chrooted) system is the one dpkg itself is built for
nativeArch = next(
    (record["Architecture"] for record in installedRecords if record["Package"] == "dpkg"),
    None
) or run(["dpkg", "--print-architecture"]).strip()

installedPackages = set()
for record in installedRecords:
    package = Package(record)
    addPackage(package)
    installedPackages.add(package)

# Not-installed packages are only needed when the input or the graph can reach them
if args.names or args.follow_unspecified_packages or args.show_missing_recommends:
    for record in parseRecords(run(aptCache + ["dumpavail"])):
        addPackage(Package(record))

def pickByArch(candidates, arch):
    for package in candidates:
        if package.arch in (arch, "all"):
            return package
    return None

# Resolve a dependency name to a package, the way a package of architecture
# `arch` would see it (real packages first, then providers of virtual ones)
def nameToPackage(name, qualifier, arch):
    if qualifier == "native":
        arch = nativeArch
    elif qualifier and qualifier != "any":
        arch = qualifier

    candidates = byName.get(name, [])
    package = pickByArch(candidates, arch)
    if package:
        return package
    for package in candidates:
        if package.multiArch in ("foreign", "allowed"):
            return package

    candidates = providers.get(name, [])
    return pickByArch(candidates, arch) or (candidates[0] if candidates else None)

inputPackages = set()

def resolveDependencyBranch(alternatives, arch, type):
    # Pick every possible or branch for simplicity if the dependency isn't one
    # of the input packages, which means we might not find all the root nodes,
    # but in practice usually isn't a problem since a branched dependency is
    # usually of libraries
    baseDependencies = set()
    for name, qualifier in alternatives:
        package = nameToPackage(name, qualifier, arch)
        if not package:
            continue

        if package in inputPackages:
            return {(package, type)}
        baseDependencies.add((package, type))
    return baseDependencies

def outputPackageList(packages):
    if len(packages) > 1:
        return "(" + " ".join(packages) + ")"
    return packages[0]

# Find the packages
fail = False
for name in args.names:
    name, _, qualifier = name.partition(":")
    package = nameToPackage(name, qualifier, nativeArch)
    if not package:
        print("Could not find in package cache:", name, file = sys.stderr)
        fail = True
        continue

    inputPackages.add(package)
if fail:
    sys.exit(1)

# Use all installed packages if no packages were specified
if len(inputPackages) == 0:
    inputPackages = set(installedPackages)

# Build our dependency graph: fullname -> set of dependency fullnames, plus
# the typed edges (a pair can be linked by both Depends and Recommends)
successors = dict()
edges = set()
visitStack = list(inputPackages)
while len(visitStack) > 0:
    package = visitStack.pop()
    if package.fullname in successors:
        continue
    successors[package.fullname] = set()

    dependencies = [(relation, "Depends") for relation in package.depends]
    if args.use_recommends:
        dependencies += [(relation, "Recommends") for relation in package.recommends]

    for relation, type in dependencies:
        for dependencyPackage, type in resolveDependencyBranch(relation, package.dependencyArch, type):
            successors[package.fullname].add(dependencyPackage.fullname)
            edges.add((package.fullname, dependencyPackage.fullname, type))

            if args.follow_unspecified_packages and dependencyPackage.fullname not in successors:
                visitStack.append(dependencyPackage)

# Dependencies that weren't followed are leaf nodes
for _, target, _ in edges:
    successors.setdefault(target, set())

# Tarjan's algorithm (iterative, package graphs are too deep for recursion)
def stronglyConnectedComponents(graph):
    index = dict()
    lowLink = dict()
    stack = []
    onStack = set()
    components = []
    for start in graph:
        if start in index:
            continue
        index[start] = lowLink[start] = len(index)
        stack.append(start)
        onStack.add(start)
        work = [(start, iter(graph[start]))]
        while len(work) > 0:
            node, children = work[-1]
            for child in children:
                if child not in index:
                    index[child] = lowLink[child] = len(index)
                    stack.append(child)
                    onStack.add(child)
                    work.append((child, iter(graph[child])))
                    break
                if child in onStack:
                    lowLink[node] = min(lowLink[node], index[child])
            else:
                work.pop()
                if len(work) > 0:
                    parent = work[-1][0]
                    lowLink[parent] = min(lowLink[parent], lowLink[node])
                if lowLink[node] == index[node]:
                    component = set()
                    while True:
                        member = stack.pop()
                        onStack.discard(member)
                        component.add(member)
                        if member == node:
                            break
                    components.append(component)
    return components

# Collapse cycles into single nodes
nodes = stronglyConnectedComponents(successors)
componentOf = {fullname: i for i, component in enumerate(nodes) for fullname in component}

# Find the nodes that have no in-edges - these are the top-level nodes
topLevelNodes = set(range(len(nodes)))
for source, targets in successors.items():
    for target in targets:
        if componentOf[source] != componentOf[target]:
            topLevelNodes.discard(componentOf[target])

# Convert the nodes back into package names
topLevelPackages = set()
for node in topLevelNodes:
    packages = inputPackages & {byFullname[fullname] for fullname in nodes[node]}
    packages = sorted(packages, key = lambda package: package.displayName)

    # The results should always be one of the input packages
    assert(len(packages) > 0)

    topLevelPackages.add(packages[0])
    print(packages[0].displayName)

# Find missing recommend packages if requested
if args.show_missing_recommends:
    recommendedVias = dict()
    for source, target, type in edges:
        if type != "Recommends":
            continue
        if byFullname[target] not in inputPackages:
            recommendedVias.setdefault(target, set()).add(source)
    for source, target, type in edges:
        if type != "Recommends":
            recommendedVias.pop(target, None)

    predecessors = dict()
    for source, target, _ in edges:
        predecessors.setdefault(target, set()).add(source)

    def ancestors(fullname):
        found = set()
        visitStack = [fullname]
        while len(visitStack) > 0:
            for predecessor in predecessors.get(visitStack.pop(), ()):
                if predecessor not in found:
                    found.add(predecessor)
                    visitStack.append(predecessor)
        return found

    for fullname, via in recommendedVias.items():
        by = topLevelPackages & {byFullname[ancestor] for ancestor in ancestors(fullname)}
        via = {byFullname[recommender] for recommender in via} - by

        name = byFullname[fullname].displayName
        via = sorted(package.displayName for package in via)
        by = sorted(package.displayName for package in by)

        print("{}-".format(name))
        print(
            "{}- is recommended by {}{}".format(
                name,
                outputPackageList(by),
                " via {}".format(outputPackageList(via)) if len(via) > 0 else ""
            ),
            file = sys.stderr
        )
