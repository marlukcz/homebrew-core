class Libhttpseverywhere < Formula
  desc "Bring HTTPSEverywhere to desktop apps"
  homepage "https://github.com/gnome/libhttpseverywhere"
  url "https://download.gnome.org/sources/libhttpseverywhere/0.8/libhttpseverywhere-0.8.1.tar.xz"
  sha256 "fa3e5ddd92da919c7da2d37bf0b08109e504ec52797ff5ec76f52362d2914280"

  bottle do
    cellar :any
    sha256 "4fa182c92219a4d1e31423eb15b2dafe2c555f99366f1d93a9f2fd70105a7bef" => :high_sierra
    sha256 "d6de7f5ccd44a84084fd2f338d270b20317d64598afcf183df8a7e93a3b115b4" => :sierra
    sha256 "92efdd3f62aee2b609dbf96fc401fc1041787abb7595127ba1b6d49243d56f6e" => :el_capitan
    sha256 "9dcae8efdf1d242fa996dd7a8854ae8da7bfddfc2c320f051d3b0779fb8a9e07" => :x86_64_linux
  end

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "vala" => :build
  depends_on "pkg-config" => :build
  depends_on "glib"
  depends_on "json-glib"
  depends_on "libsoup"
  depends_on "libgee"
  depends_on "libarchive"

  def install
    mkdir "build" do
      system "meson", "--prefix=#{prefix}", ".."
      system "ninja"
      system "ninja", "test"
      system "ninja", "install"
    end

    dir = [Pathname.new("#{lib}64"), lib/"x86_64-linux-gnu"].find(&:directory?)
    unless dir.nil?
      mkdir_p lib
      system "/bin/mv", *Dir[dir/"*"], lib
      rmdir dir
      inreplace Dir[lib/"pkgconfig/*.pc"], %r{lib64|lib/x86_64-linux-gnu}, "lib"
    end
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <httpseverywhere.h>

      int main(int argc, char *argv[]) {
        GType type = https_everywhere_context_get_type();
        return 0;
      }
    EOS
    ENV.libxml2
    gettext = Formula["gettext"]
    glib = Formula["glib"]
    json_glib = Formula["json-glib"]
    libarchive = Formula["libarchive"]
    libgee = Formula["libgee"]
    libsoup = Formula["libsoup"]
    pcre = Formula["pcre"]
    flags = (ENV.cflags || "").split + (ENV.cppflags || "").split + (ENV.ldflags || "").split
    flags += %W[
      -I#{gettext.opt_include}
      -I#{glib.opt_include}/glib-2.0
      -I#{glib.opt_lib}/glib-2.0/include
      -I#{include}/httpseverywhere-0.8
      -I#{json_glib.opt_include}/json-glib-1.0
      -I#{libarchive.opt_include}
      -I#{libgee.opt_include}/gee-0.8
      -I#{libsoup.opt_include}/libsoup-2.4
      -I#{pcre.opt_include}
      -D_REENTRANT
      -L#{gettext.opt_lib}
      -L#{glib.opt_lib}
      -L#{json_glib.opt_lib}
      -L#{libarchive.opt_lib}
      -L#{libgee.opt_lib}
      -L#{libsoup.opt_lib}
      -L#{lib}
      -larchive
      -lgee-0.8
      -lgio-2.0
      -lglib-2.0
      -lgobject-2.0
      -lhttpseverywhere-0.8
      -ljson-glib-1.0
      -lsoup-2.4
      -lxml2
    ]
    flags << "-lintl" if OS.mac?
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end
