#compdef aur

# Helper to complete aur package names
# $@ Optional extra arguments to aur pkglist
__aur_list_pkgs() {
    # Because of the large number of items causing slowdowns, only do this completion if there is
    # at least one letter. In addition we also skip processing if the current completion starts
    # with a -, which would be an option. This speeds up generating the list of options in case
    # __aur_list_pkgs is used for * (remaining positional arguments). Then we don't need to evaluate
    # any of this when we already know we are completing a flag.
    #
    # Note that additional care needs to be taken to not give the wrong behaviour for a situation
    # like "aur sync --ignore=a<tab>". That is what the IPREFIX stuff is about, it lets us skip
    # the "--ignore=" part.
    local working_data="${words[$CURRENT]#${IPREFIX}}"
    if [[ ${working_data} == "" || ${working_data[1]} == '-' ]]; then
        return
    fi

    declare -a pkgs
    pkgs=( $(aur pkglist --ttl 86400 --systime $@ 2>/dev/null) )
    # Since we are dealing with very long lists of possible completions (~80k as of writing this),
    # speed is of the utmost importance for a good user experience. A low level compadd call gave
    # the best performance in testing.
    local expl
    _description packages expl 'package'
    compadd "$expl[@]" - $pkgs
}

# Helper to list local packages.
__aur_list_local_packages() {
    declare -a pkgs
    local repo
    for repo in ${(f)"$(aur repo --list-repo)"}; do
        pkgs+=( $(aur repo -lq -d $repo 2>/dev/null) )
    done
    if [[ ${#pkgs} -eq 0 ]]; then
        _message "package (no local packages found)"
    else
        _values package $pkgs
    fi
}

# Helper to list valid repo-add attributes
__aur_list_attributes() {
    declare -a attrs
    attrs=( $(aur repo --list-attr -Sd core 2>/dev/null ) )
    if [[ ${#attrs} -eq 0 ]]; then
        _message "attr (no attributes found)"
    else
        _values attr $attrs
    fi
}

# Helper to complete repository names
# If --all is given, also complete sync repositories, not just local ones.
__aur_list_repos()
{
    if [[ $1 == '--all' ]]; then
        _values repository $(pacconf --repo-list 2>/dev/null)
    else
        declare -a repos
        repos=( $(aur repo --repo-list 2>/dev/null) )
        if [[ ${#repos} -eq 0 ]]; then
            _message "repository (none found)"
        else
            _values repository $repos
        fi
    fi
}

# Helper to call out to makepkg/makechrootpkg completion
__aur_complete_for()
{
    service=$1 $_comps[$1]
}


declare -ga _aur_build_sync_args
# Flags that are used by both aur-build and aur-sync
# Prevents having to duplicate them in both places
_aur_build_sync_args=(
    + options
    # Build args
    '*'{--margs=,--makepkg-args=}'[additional (comma separated) makepkg arguments]:arguments:_sequence __aur_complete_for
 makepkg'
    '--makepkg-conf=[the makepkg.conf to use for makepkg, for chroot also inside the container]:configuration file: _files'
    '(-A --ignore-arch)'{-A,--ignore-arch}'[ignore a missing or incomplete arch field in the build script]'
    '(-c --chroot)'{-c,--chroot}'[build packages inside a systemd-nspawn container with archbuild]'
    '(-D --directory)'{-D,--directory=}'[the base directory for containers]:directory: _files -/'
    '(-f --force)'{-f,--force}'[continue the build process if a package with the same name is found]'
    '(-L --log)'{-L,--log}'[enable logging to a text file in the build directory]'
    '(-n --no-confirm)'{-n,--no-confirm}'[do not wait for user input when installing or removing build dependencies]'
    '(-r --rmdeps)'{-r,--rmdeps}'[remove dependencies installed by makepkg]'
    '(-S --sign --gpg-sign)'{-S,--sign,--gpg-sign}'[sign build packages and the database with gpg]'
    '(-T --temp)'{-T,--temp}'[build in a temporary container]'
    '(-U --user)'{-U,--user=}'[run the host makepkg instance as the specified user]:user: _users'
    '*--bind-rw=[bind a directory read-write to the container]:directory: _files -/'
    '*--bind=[bind a directory read-only to the container]:directory: _files -/'

    # repo-add
    '--new[only add packages that are not already in the database]'
    '--prevent-downgrade[do not add packages to the database if a newer version is already present]'
    '(-R --remove)'{-R,--remove}'[remove old package files from disk when updating their entry in the database]'
    '(-v --verify)'{-v,--verify}'[verify the pgp signature of the database before updating]'

    # Repo args
    '--pacman-conf=[the pacman.conf used for syncing and retriving local repositories, for chroot also used inside the container]:configuration file: _files'
    '--root=[the root directory for the repository]:directory: _files -/'
    '(-d --database)'{-d,--database=}'[the name of the pacman database]:repository: __aur_list_repos'
)

_aur_build() {
    local -a args

    args=(
        # Note! Many flags are shared with aur-build and defined in a common $_aur_build_sync_args

        # Options
        '(-a --arg-file)'{-a,--arg-file=}'[a text file describing directories containing PKGBUILD relative to the current directory]:file: _files'
        '--dry-run[display the package names without building anything]'
        '--no-sync[do not sync the local repository after building]'
        '--pkgver[run makepkg -od before checking existing packages]'

        # Makechrootpkg options
        '(-N --namcap)'{-N,--namcap}'[run namcap on the build package]'
        '--checkpkg[run checkpkg on the build package]'

        # makepkg options
        '--no-check[do not run the check function in the PKGBUILD]'
        '(-s --syncdeps)'{-s,--syncdeps}'[install missing dependencies using pacman]'
        '(-C --clean)'{-C,--clean}'[clean up leftover work files and directories after a successful build]'
        '--buildscript[read the package script instead of the PKGBUILD]:: _files'
    )
    _arguments -s $args $_aur_build_sync_args
}

_aur_chroot() {
    local -a args

    args=(
        # Operations
        '(-B --build)'{-B,--build}'[build a package inside the container with makechrootpkg]'
        '(-U --update)'{-U,--update}'[update or create the /root copy of the container with arch-nspawn]'
        '--create[create a new container with mkarchroot]'

        # Other options
        '*--bind-rw=[bind a directory read-write to the container]:directory: _files -/'
        '*--bind=[bind a directory read-only to the container]:directory: _files -/'
        '(-D --directory)'{-D,--directory=}'[the base directory for containers]:directory: _files -/'
        '*'{--makechrootpkg-args=,--cargs=}'[additional (comma separated) arguments to be passed to makechrootpkg for --build]:arguments:_sequence __aur_complete_for
     makechrootpkg'
        '*'{--makepkg-args=,--margs=}'[additional (comma separated) makepkg arguments for makechrootpkg]:arguments:_sequence __aur_complete_for
     makepkg'
        '(-M --makepkg-conf)'{-M,--makepkg-conf=}'[the makepkg.conf to use inside the container]:configuration file: _files'
        '--path[print the path to the container template]'
        
        + '(pacman_conf)'
        {-C,--pacman-conf=}'[the pacman.conf to use inside the container]:configuration file: _files'
        {-x,--suffix=}'[the path component SUFFIX in the pacman configuration, default to extra]:suffix: '

        + positional
        '*:pkgname: __aur_list_pkgs'
    )
    _arguments -s -S $args
}

_aur_depends() {
    local -a args

    args=(
        # Dependency options
        '--no-checkdepends[do not consider checkdepends when resolving dependencies]'
        '--no-depends[do not consider depends when resolving dependencies]'
        '--no-makedepends[do not consider makedepends when resolving dependencies]'
        '--optdepends[consider optdepends when resolving dependencies]'

        + '(mode)'
        {-G,--graph}'[print dependency informatin (AUR-only) to stdout as edges]'
        {-b,--pkgbase}'[print dependency informatin (AUR-only) to stdout as pkgbase, in total order]'
        {-n,--pkgname}'[print dependency informatin (AUR-only) to stdout as pkgname, in total order]'
        {-a,--pkgname-all}'[print dependency information to stdout as pkgname in total order]'
        {-t,--table}'[output dependency information as a tab separated table]'

        + positional
        '*:pkgname: __aur_list_pkgs'
    )
    _arguments -s $args
}

_aur_fetch() {
    local -a args
    local -A sync_types

    sync_types[reset]="discard local changes"
    sync_types[merge]="run git-merge to incorporate upstream changes"
    sync_types[rebase]="run git-rebase to incorporate upstream changes"
    sync_types[fetch]="only run git-fetch"

    local -a sync_type_strings=()
    local k
    for k in ${(k)sync_types}; do
        sync_type_strings+=( "${k}\\:${sync_types[${k}]// /\\ }" )
    done

    args=(
        '--existing[if a package has no matching repository on AUR, ignore it instead of running git-clone]'
        '(-r --recurse)'{-r,--recurse}'[download packages and their dependencies with aur-depends]'
        '--results=[write colon-delimited output to FILE]:file: _files'
        '--discard[discard uncommited changes if git-rebase or git-merge result in new commits]'
        #"(--reset --no-pull)--sync=[configure handling of local changes]:mode:(($sync_type_strings))"
        "(--sync)--rebase[${sync_types[rebase]}, alias for --sync=rebase]"
        "(--sync)--reset[${sync_types[reset]}, alias for --sync=reset]"
        "(--sync)--fetch-only[${sync_types[fetch]}, alias for --sync=fetch]"
    )
    # This is to handle the fact that -r/--recurse changes the meaning of positional arguments
    if [[ $words[(ie)-r] -le ${#words} || $words[(ie)--recurse] -le ${#words} ]]; then
        _arguments -s $args '*:pkgname: __aur_list_pkgs'
    else
        _arguments -s $args '*:pkgbase: __aur_list_pkgs -b'
    fi


}

_aur_graph() {
    local -a args

    args=(
        '*:files: _files -g .SRCINFO'
    )
    _arguments -s $args
}

_aur_pkglist() {
    local -a args

    args=(
        + '(source)'
        {-b,--pkgbase}'[retrieve pkgbase.gz instead of packages.gz]'
        '--users[retrieve users.gz instead of packages.gz]'
        {-i,--info}'[retrieve AUR metadata from search-type requests]'
        {-s,--search}'[retrieve AUR metadata from info-type requests]'

        + '(mode)'
        {-F,--fixed-strings}'[interpret the given pattern as a list of fixed strings separated by newline]'
        {-P,--perl-regexp}'[interpret the given pattern as a Perl compatible regular expression]'
        '--plain[print the package list to standard output (default)]'
        {-J,--json}'[interpret the given pattern as a jq pattern (default for --search and --info)]'
        {-q,--quiet}'[update the package list and print its path to standard output]'

        + options
        '(-t --ttl)'{-t,--ttl}'[set the delay in seconds before a new list is retrived (defaullt 300)]:delay in seconds: '
        '(-v --verify)'{-v,--verify}'[verify checksums of the compressed list with sha256sum]'
    )
    _arguments -s $args
}

_aur_query() {
    local -a args

    args=(
        '(-a --any)'{-a,--any=}'[return set union of results instead of intersection]'
        '(-b --by)'{-b,--by=}'[argument for package search (--type=search)]:by:(name name-desc maintainer depends makedepends optdepends checkdepends)'
        '(-e --exit-if-empty)'{-e,--exit-if-empty}'[if no results are found, exit with status 1 instead of 0]'
        '(-r --raw)'{-r,--raw}'[do not process results (implied by --type=info)]'
        '(-t --type)'{-t,--type=}'[type of request]:type:(search info)'
        '*:pkgname: __aur_list_pkgs'
    )
    _arguments -s $args
}

_aur_repo() {
    local -a args

    args=(
        + '(operations)'
        '(upgrade)'{-F,--attr=}'[list the attribute ATTR]:attr: __aur_list_attributes'
        '(upgrade)'{-l,--list}'[list the contents of a local repository]'
        '(upgrade)'{-t,--table}'[list the contents of a local repository with more detail]'
        '(upgrade)--list-path[list the paths of configured local repositories]'
        '(upgrade)--list-repo[list the names of configured local repositories]'
        '(upgrade)--list-attr[list valid attributes for repositories generated by repo-add]'
        '(upgrade)--path[list the resolved path of the selected pacman repository]'

        + upgrade
        '(operations -u --upgrades)'{-u,--upgrades}'[check package update with aur-vercmp]'
        '(operations -a --all)'{-a,--all}'[use aur-vercmp --all when checking for upgrades, implies --upgrades]'

        + options
        '--status-file=[print status information to a specified file]:file: _files'
        '(-c --config)'{-c,--config=}'[set an alternate pacman.conf file path]:config file: _files'
        '(-d --database --repo)'{-d,--database=,--repo=}'[the name of a pacman repository]:repository: __aur_list_repos --all'
        '(-q --quiet)'{-q,--quiet}'[only print package names]'
        '(-r --root)'{-r,--root=}'[the path to the root of a local repository]:path: _files -/'
        '(-S --sync)'{-S,--sync}'[query repositories in DBPATH/sync]'
    )
    _arguments -s $args
}

_aur_repo-filter() {
    local -a args

    args=(
        '(-a --all --sync)'{-a,--all,--sync}'[query all available pacman repositories (pacsift --sync)]'
        '--config=[set an alternate pacman.conf file path]:config file: _files'
        '(-d --database)'{-d,--database=}'[restrict output to pacman repository]:repository: __aur_list_repos --all'
        '--sysroot[set an alternative system root]:path: _files -/'
    )
    _arguments -s $args
}

_aur_search() {
    local -a args

    # Groups (+ name) are used to simplify handling of options being exclusive
    # Groups with () in the name are auto-exlusive with themselves
    args=(
        + '(type)'
        {-i,--info}'[Use the info interface]'
        {-s,--search}'[Use the searchby interface (default)]'

        + '(format)'
        {-q,--short}'[only display package name, version and description]'
        {-v,--verbose}'[display more package information]'
        '--table[display output in tsv format]'

        + options
        '(-a --any)'{-a,--any}'[show the union of results instead of the intersection]'
        '(-r --json)'{-r,--json}'[display results as json]'
        '(-k --key)'{-k,--key=}'[sort results via key]:key:(Name Version NumVotes Description PackageBase URL Popularity OutOfDate Maintainer FirstSubmitted LastModified)'

        + '(search_by)'
        {-d,--desc}'[search by package name and description]'
        {-m,--maintainer}'[search by maintainer]'
        {-n,--name}'[search by package name]'
        '--depends[search for packages with keywords in depends]'
        '--makedepends[search for packages with keywords in makedepends]'
        '--optdepends[search for packages with keywords in optdepends]'
        '--checkdepends[search for packages with keywords in checkdepends]'

        + positional
    )
    # Determine if this is an info search by checking if the index of -i or --info in the words
    # array is less than the length of the array.
    if [[ $words[(ie)-i] -le ${#words} || $words[(ie)--info] -le ${#words} ]]; then
        _arguments -s $args '*:search term: __aur_list_pkgs'
    else
        _arguments -s $args '*:search term: '
    fi
}

_aur_srcver() {
    local -a args

    args=(
        '--buildscript[read the package script instead of the PKGBUILD]:: _files'
        {-j,--jobs=}'[set the amount of makepkg processes run in parallel]:number of jobs: '
        '--no-prepare[do not run the prepare() function in the PKGBUILD]'
        '*:pkgbase: __aur_list_pkgs -b'
    )
    _arguments -s $args
}

_aur_sync() {
    local -a args

    # Groups (+ name) are used to simplify handling of options being exclusive
    args=(
        # Note! Many flags are shared with aur-build and defined in a common $_aur_build_sync_args
        
        '--continue[do not download package files]'
        '--format=[generate diffs with git-diff or git-log]:format:((diff\:use\ git-diff log\:use\ git-log))'
        '--ignore-file=[ignore package upgrades listed in FILE]:file: _files'
        '--no-check[do not handle checkdepends]'
        '--no-graph[do not verify the AUR dependency graph with aur-graph]'
        '--no-view[do not present build files for inspection]'
        '--pkgver[run makepkg -od --noprepare before the build process]'
        '(--no-provides)--provides-from=:directories: _dir_list -s, -S'
        '(--provides-from)--no-provides[do not take virtual dependencies (provides) in pacman sync repositories into account to resolve package dependencies]'
        '(-o --no-build)'{-o,--no-build}'[print target packages and their paths instead of building them]'
        '(-u --upgrades)'{-u,--upgrades}'[update all obsolete AUR packages in a local repository]'
        '*--ignore=:package: __aur_list_local_packages'

        # These overwrite each other and are thus mutually exlusive
        + '(no_ver)'
        '--no-ver[disable version checking for packages]'
        '--no-ver-argv[disable version checking for packages specified on the command line or upgrade candidates from --upgrades]'
        '--rebuild[alias for -f --nover-argv]'
        '--rebuild-all[alias for -f --nover]'
        '--rebuild-tree[as --rebuild-tree, but append all packages in the repository (see -d) as targets]'

       + positional
        '*:packages: __aur_list_pkgs'
    )
    _arguments -s $args $_aur_build_sync_args
}

_aur_vercmp() {
    local -a args

    args=(
        '(-a --all -c --current)'{-a,--all}'[show packages with an older or equal version in the AUR]'
        '(-c --current -a --all)'{-c,--current}'[changes format to print packages with an equal or newer version to stdout]'
        '(-p --path)'{-p,--path}'[read package versions from FILE instead of the AUR]: _files'
        '(-q --quiet)'{-q,--quiet}'[only print package names to standard output]'
        '(-u --upair)'{-u,--upair}'[print unpairable lines from file FILENUM where filenum is 1 or 2]:file number:(1 2)'
    )
    _arguments -s $args
}

_aur_view() {
    local -a args

    args=(
        '--format=[generate diffs with git-diff or git-log]:format:((diff\:use\ git-diff log\:use\ git-log))'
        '(-a --arg-file)'{-a,--arg-file}'[a textfile describing git repositories relative to the current directory]: file: _files'
        '--revision=[the revision used for comparing changes (defaults to HEAD)]:revision: '
        '--no-patch[suppress patch output, only showing a summary]'
        '(-a --arg-file)*:repositories: _files -/'
    )
    _arguments -s $args
}

# Main entry point and handler of top level completion
_aur() {
    local context state state_descr line
    typeset -A opt_args

    local -A cmds
    cmds[build]="build packages to a local repository"
    cmds[chroot]="build pacman packages with systemd-nspawn"
    cmds[depends]="retrieve dependencies using aurweb"
    cmds[fetch]="fetch packages from a location"
    cmds[graph]="print package/dependency directed graph"
    cmds[pkglist]="print the AUR package list"
    cmds[query]="send GET requests to the aurweb RPC interface"
    cmds[repo-filter]="filter packages in the Arch Linux repositories"
    cmds[repo]="manage local repositories"
    cmds[search]="search for AUR packages"
    cmds[srcver]="list version of VCS packages"
    cmds[sync]="download and build AUR packages automatically"
    cmds[vercmp]="check packages for AUR updates"
    cmds[view]="inspect git repositories"

    local -a descs=()
    local k
    for k in ${(k)cmds}; do
        descs+=( "${k}\\:${cmds[${k}]// /\\ }" )
    done

    _arguments -C \
        "1:command:((${descs} --version\:display\ version))" \
        '*::arg:->options'

    case $state in
        options)
            if [[ ${cmds[${words[1]}]} != "" ]]; then
                _aur_${words[1]}
            fi
            ;;
    esac
}
