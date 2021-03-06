set __fundle_current_version '0.7.0'
function __fundle_seq -a upto # {{{
    seq 1 1 $upto 2>/dev/null
end
# }}}
function __fundle_next_arg -a index # {{{
    set -l args $argv[2..-1]
    set -l arg_index (math $index + 1)
    if test (count $args) -lt $arg_index
        echo "missing argument for $args[$index]"
        return 1
    end
    set -l arg $args[$arg_index]
    switch $arg
        case '--*'
            echo "expected argument for $args[$index], got $arg"
            and return 1
        case '*'
            echo $arg
            and return 0
    end
end
# }}}
function __fundle_compare_versions -a version1 -a version2 # {{{
    for i in (__fundle_seq 4)
        set -l v1 (echo $version1 | cut -d '.' -f $i | sed -Ee 's/[a-z]+//g')
        set -l v2 (echo $version2 | cut -d '.' -f $i | sed -Ee 's/[a-z]+//g')
        if test \( -n $v1 -a -z $v2 \) -o \( -n $v1 -a -n $v2 -a $v1 -lt $v2 \)
            echo -n "lt"
            and return 0
        else if test \( -z $v1 -a -n $v2 \) -o \( -n $v1 -a -n $v2 -a $v1 -gt $v2 \)
            echo -n "gt"
            and return 0
        end
    end
    echo -n "eq"
    and return 0
end
# }}}
function __fundle_date -d "returns a date" # {{{
    set -l d (date +%s%N)
    if echo $d | string match -rvq 'N'
        echo $d
    else
        gdate +%s%N
    end
    return 0
end
# }}}
function __fundle_self_update -d "updates fundle" # {{{
    set -l fundle_repo_url "https://github.com/comfortablynick/fundle.git"
    # This `sed` stays for now since doing it easily with `string` requires "--filter", which is only in 2.6.0
    set -l latest (command git ls-remote --tags $fundle_repo_url | sed -n -e 's|.*refs/tags/v\(.*\)|\1|p' | tail -n 1)
    if test (__fundle_compare_versions $latest (__fundle_version)) != "gt"
        echo "fundle is already up to date"
        and return 0
    else
        set -l file_url_template 'https://raw.githubusercontent.com/comfortablynick/fundle/VERSION/functions/fundle.fish'
        set -l file_url (string replace 'VERSION' -- "v$latest" $file_url_template)
        set -l tmp_file (mktemp /tmp/fundle.XXX)
        set -l update_message "fundle has been updated to version $latest"
        curl -Ls $file_url >$tmp_file
        and mv $tmp_file (status -f)
        and echo $update_message
        and return 0
    end
end
# }}}
function __fundle_url_rev -d "prints the revision from the url" -a git_url # {{{
    set -l rev (echo $git_url | cut -d '#' -f 2 -s)
    if test -n "$rev"
        echo $rev
    else
        echo master
    end
end
# }}}
function __fundle_remote_url -d "prints the remote url from the full git url" -a git_url # {{{
    echo $git_url | cut -d '#' -f 1
end
# }}}
function __fundle_rev_parse -d "prints the revision if any" -a dir -a commitish # {{{
    set -l sha (command git --git-dir $dir rev-parse -q --verify $commitish 2>/dev/null)
    if test $status -eq 0
        echo -n $sha
        return 0
    end
    return 1
end
# }}}
function __fundle_commit_sha -d "returns sha of the commit-ish" -a dir -a commitish # {{{
    if test -d "$dir/.git"
        set dir "$dir/.git"
    end
    if __fundle_rev_parse $dir "origin/$commitish"
        return 0
    end
    __fundle_rev_parse $dir $commitish
end
# }}}
function __fundle_plugins_dir -d "returns fundle directory" # {{{
    if test -z "$fundle_plugins_dir"
        if test -n "$XDG_DATA_HOME"
            echo $XDG_DATA_HOME/fundle
        else
            echo $HOME/.local/share/fundle
        end
    else
        echo $fundle_plugins_dir
    end
end
# }}}
function __fundle_no_git -d "check if git is installed" # {{{
    # `command -q` is >= 2.5.0
    if not command -s git >/dev/null 2>&1
        echo "git needs to be installed and in the path"
        return 0
    end
    return 1
end
# }}}
function __fundle_check_date -d "check date" # {{{
    if date +%s%N | string match -rvq 'N'
        return 0
    end
    if command -s gdate >/dev/null 2>&1
        return 0
    end
    echo "You need to have a GNU date compliant date installed to use profiling. Use 'brew install coreutils' on OSX"
    return 1
end
# }}}
function __fundle_get_url -d "returns the url for the given plugin" -a repo # {{{
    echo "https://github.com/$repo.git"
end
# }}}
function __fundle_update_plugin -d "update the given plugin" -a git_dir -a remote_url # {{{
    command git --git-dir=$git_dir remote set-url origin $remote_url 2>/dev/null
    and \
        command git --git-dir=$git_dir fetch -q 2>/dev/null
end
# }}}
function __fundle_install_plugin -d "install/update the given plugin" -a plugin -a git_url # {{{
    if __fundle_no_git
        return 1
    end

    set -l plugin_dir (__fundle_plugins_dir)/$plugin
    set -l git_dir $plugin_dir/.git
    set -l remote_url (__fundle_remote_url $git_url)
    set -l update ""

    if contains __update $argv
        set update true
    end

    if test -d $plugin_dir
        if test -n "$update"
            echo "Updating $plugin"
            __fundle_update_plugin $git_dir $remote_url
        else
            echo "$argv[1] installed in $plugin_dir"
            return 0
        end
    else
        echo "Installing $plugin"
        command git clone -q $remote_url $plugin_dir
    end

    set -l sha (__fundle_commit_sha $git_dir (__fundle_url_rev $git_url))
    if test $status -eq 0
        command git --git-dir="$git_dir" --work-tree="$plugin_dir" checkout -q -f $sha
    else
        echo "Could not update $plugin"
        return 1
    end
end
# }}}
function __fundle_show_doc_msg -d "show a link to fundle docs" # {{{
    if test (count $argv) -ge 1
        echo $argv
    end
    echo "See the docs for more info. https://github.com/comfortablynick/fundle"
end
# }}}
function __fundle_load_plugin -a plugin -a path -a fundle_dir -a profile -d "load a plugin" # {{{
    if begin
            set -q __fundle_loaded_plugins
            and contains $plugin $__fundle_loaded_plugins
        end
        return 0
    end

    set -l plugin_dir (string replace -r '/.$' '' -- "$fundle_dir/$plugin/$path")

    if not test -d $plugin_dir
        __fundle_show_doc_msg "$plugin not installed. You may need to run 'fundle install'"
        return 0
    end

    # Take everything but "plugin-" from the last path component
    set -l plugin_name (string replace -r '.*/(plugin-)?(.*)$' '$2' -- $plugin)
    set -l init_file "$plugin_dir/init.fish"
    set -l conf_dir "$plugin_dir/conf.d"
    set -l bindings_file "$plugin_dir/key_bindings.fish"
    set -l functions_dir "$plugin_dir/functions"
    set -l completions_dir "$plugin_dir/completions"
    set -l plugin_paths $__fundle_plugin_name_paths

    if begin
            test -d $functions_dir
            and not contains $functions_dir $fish_function_path
        end
        set fish_function_path $functions_dir $fish_function_path
    end

    if begin
            test -d $completions_dir
            and not contains $completions_dir $fish_complete_path
        end
        set fish_complete_path $completions_dir $fish_complete_path
    end

    if test -f $init_file
        source $init_file
    else if test -d $conf_dir
        # read all *.fish files in conf.d
        for f in $conf_dir/*.fish
            source $f
        end
    else
        # read all *.fish files if no init.fish or conf.d found
        for f in $plugin_dir/*.fish
            source $f
        end
    end

    if test -f $bindings_file
        set -g __fundle_binding_paths $bindings_file $__fundle_binding_paths
    end

    set -g __fundle_loaded_plugins $plugin $__fundle_loaded_plugins

    set -l dependencies (printf '%s\n' $plugin_paths $__fundle_plugin_name_paths | sort | uniq -u)
    for dependency in $dependencies
        set -l name_path (string split : -- $dependency)
        if test "$profile" -eq 1
            set -l start_time (__fundle_date +%s%N)
            __fundle_load_plugin $name_path[1] $name_path[2] $fundle_dir $profile
            set -l ellapsed_time (math \((__fundle_date +%s%N) - $start_time\) / 1000)
            echo "$name_path[1]": {$ellapsed_time}us
        else
            __fundle_load_plugin $name_path[1] $name_path[2] $fundle_dir $profile
        end
    end

    emit "init_$plugin_name" $plugin_dir
end
# }}}
function __fundle_bind -d "set up bindings" # {{{
    if functions -q fish_user_key_bindings
        and not functions -q __fish_user_key_bindings
        functions -c fish_user_key_bindings __fish_user_key_bindings
    end

    function fish_user_key_bindings
        for bindings in $__fundle_binding_paths
            source $bindings
        end
        if functions -q __fish_user_key_bindings
            __fish_user_key_bindings
        end
    end
end
# }}}
function __fundle_init -d "initialize fundle" # {{{
    set -l fundle_dir (__fundle_plugins_dir)

    if test (count $__fundle_plugin_names) -eq 0
        __fundle_show_doc_msg "No plugin registered. You need to call 'fundle plugin NAME' before using 'fundle init'. \

Try reloading your shell if you just edited your configuration."
        return 1
    end

    set -l profile 0
    if begin
            contains -- -p $argv
            or contains -- --profile $argv
            and __fundle_check_date
        end
        set profile 1
    end

    for name_path in $__fundle_plugin_name_paths
        set -l name_path (string split : -- $name_path)
        if test "$profile" -eq 1
            set -l start_time (__fundle_date +%s%N)
            __fundle_load_plugin $name_path[1] $name_path[2] $fundle_dir $profile
            set -l ellapsed_time (math \((__fundle_date +%s%N) - $start_time\) / 1000)
            echo "$name_path[1]": {$ellapsed_time}us
        else
            __fundle_load_plugin $name_path[1] $name_path[2] $fundle_dir $profile
        end
    end

    __fundle_bind
end
# }}}
function __fundle_install -d "install plugin" # {{{
    if test (count $__fundle_plugin_names) -eq 0
        __fundle_show_doc_msg "No plugin registered. You need to call 'fundle plugin NAME' before using 'fundle install'"
    end

    if begin
            contains -- -u $argv
            or contains -- --upgrade $argv
        end
        echo "deprecation warning: please use 'fundle update' to update plugins"
        set argv $argv __update
    end

    for i in (__fundle_seq (count $__fundle_plugin_names))
        __fundle_install_plugin $__fundle_plugin_names[$i] $__fundle_plugin_urls[$i] $argv
    end

    set -l original_plugins_count (count (__fundle_list -s))
    __fundle_init

    # if plugins count increase after init, new plugins have dependencies
    # install new plugins dependencies if any
    if test (count (__fundle_list -s)) -gt $original_plugins_count
        __fundle_install $argv
    end
end
# }}}
function __fundle_clean -d "cleans fundle directory" # {{{
    set -l fundle_dir (__fundle_plugins_dir)
    set -l used_plugins (__fundle_list -s)
    set -l installed_plugins $fundle_dir/*/*/
    for installed_plugin in $installed_plugins
        set -l plugin (string trim --chars="/" \
									(string replace -r -- "$fundle_dir" "" $installed_plugin))
        if not contains $plugin $used_plugins
            echo "Removing $plugin"
            rm -rf $fundle_dir/$plugin
        end
    end
end
# }}}
function __fundle_plugin --d 'add plugin to fundle' # {{{
    set -l options 'u/url=' 'p/path=' 'c/cond=' 'h/help' 'd/debug'
    set -l help_txt "usage: fundle plugin NAME [[--url URL ] [--path PATH] [--cond CONDITION]]"
    test -z "$argv" && echo $help_txt && return 1
    argparse $options -- $argv

    set -l plugin_url ""
    set -l plugin_path "."
    set -l plugin_cond ""
    set -l eval_debug ""
    set -l name ""

    # Process options
    set -q _flag_help && echo "$help_txt" && return 0
    set -q _flag_url && set plugin_url $_flag_url
    set -q _flag_path && set plugin_path $_flag_path
    set -q _flag_cond && set plugin_cond $_flag_cond || set plugin_cond "true"

    if test -z "$argv"
        echo "NAME is required!"
        echo $help_txt
    else
        set name $argv
    end

    if echo "$plugin_cond" | source
        set -l cond_true
        set eval_debug "Cond true"

        # Process plugin
        test -z "$plugin_url"
        and set plugin_url (__fundle_get_url $name)
        if not contains $name $__fundle_plugin_names
            and set -q $cond_true
            set -g __fundle_plugin_names $__fundle_plugin_names $name
            set -g __fundle_plugin_urls $__fundle_plugin_urls $plugin_url
            set -g __fundle_plugin_name_paths $__fundle_plugin_name_paths $name:$plugin_path
        end
    else
        set eval_debug "Cond false"
    end

    if set -q _flag_debug
        echo "----- DEBUG OUTPUT -----"
        echo "Fundle args for $name:"
        echo "  Url: $plugin_url"
        echo "  Path: $plugin_path"
        echo "  Cond eval: $eval_debug"
        echo ""
        echo "Fundle vars:"
        echo "  Plugin names: $__fundle_plugin_names"
        echo "  Plugin urls: $__fundle_plugin_urls"
        echo "  Plugin name+paths: $__fundle_plugin_name_paths"
        echo "----- END DEBUG -----"
    end
end
# }}}
function __fundle_plug --d 'add plugin to fundle' # {{{
    set -l help_txt "usage: fundle plugin NAME [[--url URL ] [--path PATH] [--cond CONDITION]]"
    test -z "$argv" && echo $help_txt && return 1

    set -l arglist ""
    set -l plugin_url ""
    set -l plugin_path "."
    set -l plugin_cond ""
    set -l eval_debug ""
    set -l name ""

    # Process options
    echo $argv
    set arglist (string split ", " "$argv")

    # TODO: use awk to parse?
    for arg in $argv
        echo "$arg"
    end
    return

    if echo "$plugin_cond" | source
        set -l cond_true
        set eval_debug "Cond true"

        # Process plugin
        test -z "$plugin_url"
        and set plugin_url (__fundle_get_url $name)
        if not contains $name $__fundle_plugin_names
            and set -q $cond_true
            set -g __fundle_plugin_names $__fundle_plugin_names $name
            set -g __fundle_plugin_urls $__fundle_plugin_urls $plugin_url
            set -g __fundle_plugin_name_paths $__fundle_plugin_name_paths $name:$plugin_path
        end
    else
        set eval_debug "Cond false"
    end

    if set -q _flag_debug
        echo "----- DEBUG OUTPUT -----"
        echo "Fundle args for $name:"
        echo "  Url: $plugin_url"
        echo "  Path: $plugin_path"
        echo "  Cond eval: $eval_debug"
        echo ""
        echo "Fundle vars:"
        echo "  Plugin names: $__fundle_plugin_names"
        echo "  Plugin urls: $__fundle_plugin_urls"
        echo "  Plugin name+paths: $__fundle_plugin_name_paths"
        echo "----- END DEBUG -----"
    end
end
# }}}
function __fundle_version -d "prints fundle version" # {{{
    echo $__fundle_current_version
end
# }}}
function __fundle_print_help -d "prints fundle help" # {{{
    echo "usage: fundle (init | plugin | list | install | update | clean | self-update | version | help)"
end
# }}}
function __fundle_list -d "list registered plugins" # {{{
    if begin
            contains -- -s $argv
            or contains -- --short $argv
        end
        for name in $__fundle_plugin_names
            echo $name
        end
    else
        for i in (__fundle_seq (count $__fundle_plugin_names))
            echo {$__fundle_plugin_names[$i]}\n\t{$__fundle_plugin_urls[$i]}
        end
    end
end
# }}}
function fundle -d "run fundle" # {{{
    if __fundle_no_git
        return 1
    end

    set -l sub_args ""

    switch (count $argv)
        case 0
            __fundle_print_help
            return 1
        case 1
        case '*'
            set sub_args $argv[2..-1]
    end

    switch $argv[1]
        case "init"
            __fundle_init $sub_args
        case "plugin"
            __fundle_plugin $sub_args
        case "load"
            __fundle_load $sub_args
        case "list"
            __fundle_list $sub_args
        case "plugins"
            echo "'fundle plugins' has been replaced by 'fundle list'"
        case "install"
            __fundle_install $sub_args
        case "update"
            __fundle_install __update $sub_args
        case "clean"
            __fundle_clean
        case "self-update"
            __fundle_self_update
        case "version" -v --version
            __fundle_version
        case "help" -h --help
            __fundle_print_help
            return 0
        case "*"
            __fundle_plug $argv
            # __fundle_print_help
            return 0
    end
end
# }}}
# vim:set fdm=marker
