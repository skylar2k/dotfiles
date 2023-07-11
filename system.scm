;; This is an operating system configuration generated
;; by the graphical installer.
;;
;; Once installation is complete, you can learn and modify
;; this file to tweak the system configuration, and pass it
;; to the 'guix system reconfigure' command to effect your
;; changes.


;; Indicate which modules to import to access the variables
;; used in this configuration.
(use-modules (gnu)
			 (nongnu packages linux)
			 (nongnu system linux-initrd))
(use-service-modules cups desktop networking ssh xorg)
(use-package-modules security-token)

(operating-system
  (locale "en_US.utf8")
  (timezone "Europe/Oslo")
  (keyboard-layout (keyboard-layout "no"))
  (host-name "guix")
  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))

  ;; The list of user accounts ('root' is implicit).
  (users (cons* (user-account
                  (name "init5")
                  (comment "init5")
                  (group "users")
                  (home-directory "/home/init5")
                  (supplementary-groups '("wheel" "netdev" "audio" "video" "plugdev")))
                %base-user-accounts))

  ;; Packages installed system-wide.  Users can also install packages
  ;; under their own account: use 'guix search KEYWORD' to search
  ;; for packages and 'guix install PACKAGE' to install a package.
  (packages (append (list (specification->package "nss-certs")
						  (specification->package "sway"))
                    %base-packages))

  ;; Below is the list of system services.  To search for available
  ;; services, run 'guix system search KEYWORD' in a terminal.
  (services (cons*
			  (udev-rules-service 'fido2 libfido2 #:groups '("plugdev"))
			  (modify-services %desktop-services
  							 (delete gdm-service-type))))

  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (targets (list "/boot/efi"))
                (keyboard-layout keyboard-layout)))
  (swap-devices (list (swap-space
                        (target (uuid
                                 "2d55cb03-e7a6-4232-8028-3db648571bd2")))))
  ;; The list of file systems that get "mounted".  The unique
  ;; file system identifiers there ("UUIDs") can be obtained
  ;; by running 'blkid' in a terminal.
  (file-systems (cons* (file-system
                         (mount-point "/boot/efi")
                         (device (uuid "053B-17EC"
                                       'fat16))
                         (type "vfat"))
                       (file-system
                         (mount-point "/")
                         (device (uuid
                                  "2b1d903a-576d-4025-89cc-479c099ef6bf"
                                  'ext4))
                         (type "ext4")) %base-file-systems)))
