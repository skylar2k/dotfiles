(define-module (gnu packages lua)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module (guix licenses))

(define-public lua-format
  (package
    (name "lua-format")
    (version "1.3.6")
    (source (origin
              (method git-fetch)
              (uri (git-reference
					 (url "https://github.com/Koihik/LuaFormatter")
					 (commit version)
					 (recursive? #t)))
			  (file-name (git-file-name name version))
              (sha256
               (base32
                "0440kdab5i0vhlk71sbprdrhg362al8jqpy7w2vdhcz1fpi5cm0b"))
			  (modules '((guix build utils)))
			  (snippet
				'(substitute* '("third_party/Catch2/single_include/catch2/catch.hpp")
							  (("MINSIGSTKSZ")
							   "16384")))))
    (build-system cmake-build-system)
    (synopsis "Lua-format")
    (description "lua-format")
    (home-page "https://github.com/Koihik/LuaFormatter")
    (license gpl3+)))

lua-format
