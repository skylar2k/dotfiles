;; This "home-environment" file can be passed to 'guix home reconfigure'
;; to reproduce the content of your profile.  This is "symbolic": it only
;; specifies package names.  To reproduce the exact same profile, you also
;; need to capture the channels being used, as returned by "guix describe".
;; See the "Replicating Guix" section in the manual.

(use-modules (gnu home)
             (gnu packages)
             (gnu packages ssh)
             (gnu packages vim)
             (gnu packages terminals)
             (gnu packages xdisorg)
             (gnu packages rust-apps)
             (nongnu packages mozilla)
             (gnu services)
             (guix gexp)
             (gnu home services)
             (gnu home services ssh)
             (gnu home services shells))

(home-environment
  ;; Below is the list of packages that will show up in your
  ;; Home profile, under ~/.guix-home/profile.
  (packages (specifications->packages (list "neovim" ;Terminal tools
                                            "ripgrep"
                                            "alacritty"
                                            "git"
                                            "openssh"
                                            "bemenu" ;WM stuff
                                            "firefox")))

  ;; Below is the list of Home services.  To search for available
  ;; services, run 'guix home search KEYWORD' in a terminal.
  (services
   (list (service home-bash-service-type
                  (home-bash-configuration
                   (bashrc (list (local-file "files/bashrc")))
                   (bash-profile (list (local-file "files/bash_profile")))))
         (simple-service 'setup-xdg-home-config
                         home-xdg-configuration-files-service-type
                         `(("nvim/init.lua" ,(local-file "files/nvim/init.lua"))
                           ("sway/config" ,(local-file "files/sway"))
                           ("alacritty.yml" ,(local-file "files/alacritty.yml"))
                           ("guix/channels.scm" ,(local-file "channels.scm"))))
         (service home-openssh-service-type)
         (service home-ssh-agent-service-type))))
