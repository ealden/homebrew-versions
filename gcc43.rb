require 'formula'

class Gcc43 < Formula
  def arch
    if Hardware::CPU.type == :intel
      if MacOS.prefer_64_bit?
        'x86_64'
      else
        'i686'
      end
    elsif Hardware::CPU.type == :ppc
      if MacOS.prefer_64_bit?
        'powerpc64'
      else
        'powerpc'
      end
    end
  end

  def osmajor
    `uname -r`.chomp
  end

  homepage 'http://gcc.gnu.org'
  url 'http://ftpmirror.gnu.org/gcc/gcc-4.3.6/gcc-4.3.6.tar.bz2'
  mirror 'http://ftp.gnu.org/gnu/gcc/gcc-4.3.6/gcc-4.3.6.tar.bz2'
  sha1 'df276018e3c664c7e6aa7ca88a180515eea61663'

  option 'enable-cxx', 'Build the g++ compiler'
  option 'enable-fortran', 'Build the gfortran compiler'
  option 'enable-java', 'Buld the gcj compiler'
  option 'enable-objc', 'Enable Objective-C language support'
  option 'enable-objcxx', 'Enable Objective-C++ language support'
  option 'enable-all-languages', 'Enable all compilers and languages, except Ada'
  option 'enable-nls', 'Build with native language support (localization)'
  option 'enable-profiled-build', 'Make use of profile guided optimization when bootstrapping GCC'
  option 'enable-multilib', 'Build with multilib support'

  depends_on 'gmp4'
  depends_on 'mpfr2'
  depends_on 'ecj' if build.include? 'enable-java' or build.include? 'enable-all-languages'

  def patches
    { # Patches from macports
      :p0 => [
        # Fix building on darwin10
        'http://trac.macports.org/export/110576/trunk/dports/lang/gcc43/files/darwin10.diff',
        # Fix multilib
        'http://trac.macports.org/export/110576/trunk/dports/lang/gcc43/files/i386_multilib.diff',
        # Build fix for Snow Leopard
        'http://trac.macports.org/export/110576/trunk/dports/lang/gcc43/files/Make-lang.in.diff',
        # Fix libffi fix for ppc
        'http://trac.macports.org/export/110576/trunk/dports/lang/gcc43/files/ppc_fde_encoding.diff'
      ]
    }
  end

  def install
    # GCC will suffer build errors if forced to use a particular linker.
    ENV.delete 'LD'

    if build.include? 'enable-all-languages'
      # Everything but Ada, which requires a pre-existing GCC Ada compiler
      # (gnat) to bootstrap.
      languages = %w[c c++ fortran java objc obj-c++]
    else
      # The C compiler is always built, but additional defaults can be added
      # here.
      languages = %w[c]

      languages << 'c++' if build.include? 'enable-cxx'
      languages << 'fortran' if build.include? 'enable-fortran'
      languages << 'java' if build.include? 'enable-java'
      languages << 'objc' if build.include? 'enable-objc'
      languages << 'obj-c++' if build.include? 'enable-objcxx'
    end

    # Sandbox the GCC lib, libexec and include directories so they don't wander
    # around telling small children there is no Santa Claus. This results in a
    # partially keg-only brew following suggestions outlined in the "How to
    # install multiple versions of GCC" section of the GCC FAQ:
    #     http://gcc.gnu.org/faq.html#multiple
    gcc_prefix = prefix + 'gcc'

    args = [
      "--build=#{arch}-apple-darwin#{osmajor}",
      # Sandbox everything...
      "--prefix=#{gcc_prefix}",
      # ...except the stuff in share...
      "--datadir=#{share}",
      "--mandir=#{man}",
      # ...and the binaries...
      "--bindir=#{bin}",
      # ...which are tagged with a suffix to distinguish them.
      "--enable-languages=#{languages.join(',')}",
      "--program-suffix=-#{version.to_s.slice(/\d\.\d/)}",
      "--with-gmp=#{Formula.factory('gmp4').opt_prefix}",
      "--with-mpfr=#{Formula.factory('mpfr2').opt_prefix}",
      "--with-system-zlib",
      "--enable-stage1-checking",
      "--enable-checking=release",
      # a no-op unless --HEAD is built because in head warnings will raise errs.
      "--disable-werror"
    ]

    args << '--disable-nls' unless build.include? 'enable-nls'

    if build.include? 'enable-java' or build.include? 'enable-all-languages'
      args << "--with-ecj-jar=#{Formula.factory('ecj').opt_prefix}/share/java/ecj.jar"
    end

    if build.include? 'enable-multilib'
      args << '--enable-multilib'
    else
      args << '--disable-multilib'
    end

    mkdir 'build' do
      unless MacOS::CLT.installed?
        # For Xcode-only systems, we need to tell the sysroot path.
        # 'native-system-header's will be appended
        args << "--with-native-system-header-dir=/usr/include"
        args << "--with-sysroot=#{MacOS.sdk_path}"
      end

      system '../configure', *args

      # Flags for Clang compatibility
      make_flags = 'BOOT_CFLAGS="$BOOT_CFLAGS -D_FORTIFY_SOURCE=0" STAGE1_CFLAGS="$STAGE1_CFLAGS -std=gnu89 -D_FORTIFY_SOURCE=0 -fkeep-inline-functions"'

      if build.include? 'enable-profiled-build'
        # Takes longer to build, may bug out. Provided for those who want to
        # optimise all the way to 11.
        system "make #{make_flags} profiledbootstrap"
      else
        system "make #{make_flags} bootstrap"
      end

      # At this point `make check` could be invoked to run the testsuite. The
      # deja-gnu formula must be installed in order to do this.

      system 'make install'

      # Remove conflicting manpages in man7
      man7.rmtree
    end
  end
end
