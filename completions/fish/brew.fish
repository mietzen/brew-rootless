ade is available for bundle command and its check subcommand
__fish_brew_complete_arg 'bundle; and [ (count (__fish_brew_args)) = 1 ];
        or __fish_brew_subcommand bundle check
    ' -l no-upgrade -d "Don't run brew upgrade for outdated dependencies"


################
### SERVICES ###

__fish_brew_complete_cmd 'services' "Integrates Homebrew formulae with macOS's launchctl manager"
__fish_brew_complete_arg 'services; and [ (count (__fish_brew_args)) = 1 ]' -s v -l verbose -d "Print more details"

__fish_brew_complete_sub_cmd 'services' 'list'    "List all running services for the current user"
__fish_brew_complete_sub_cmd 'services' 'run'     "Run service without starting at login/boot"
__fish_brew_complete_sub_cmd 'services' 'start'   "Start service immediately and register it to launch at login/boot"
__fish_brew_complete_sub_cmd 'services' 'stop'    "Stop service immediately and unregister it from launching at login/boot"
__fish_brew_complete_sub_cmd 'services' 'restart' "Stop and start service immediately and register it to launch at login/boot"
__fish_brew_complete_sub_cmd 'services' 'cleanup' "Remove all unused services"

__fish_brew_complete_sub_arg 'services' 'run start stop restart' -l all -d "Run all available services"
__fish_brew_complete_sub_arg 'services' 'run start stop restart' -a '(__fish_brew_suggest_services)'
