class Protobuf < Formula
  desc "Protocol buffers (Google's data interchange format)"
  homepage "https://github.com/google/protobuf/"
  url "https://github.com/google/protobuf/archive/v3.5.1.tar.gz"
  sha256 "826425182ee43990731217b917c5c3ea7190cfda141af4869e6d4ad9085a740f"
  revision 1
  head "https://github.com/google/protobuf.git"

  bottle do
    sha256 "89d3e4a62799951c2a908f102ed305691f0fd0141b27c4337ef9bfe64840d8a9" => :high_sierra
    sha256 "917abbf787422c4702b3104f5f6fb77f48dae573284f5aa7a9a2ef53793e5834" => :sierra
    sha256 "5a0956aa0639b5943bee597942e7c0ab1439f2db6e322423a72a5ad68e28af82" => :el_capitan
    sha256 "de3b1b0c5ac1187fd59489d37f4cb9a7cd22cc35870dfedda3daece315ef0893" => :x86_64_linux
  end

  # this will double the build time approximately if enabled
  option "with-test", "Run build-time check"
  option "without-python@2", "Build without python2 support"

  deprecated_option "with-check" => "with-test"
  deprecated_option "without-python" => "with-python@2"
  deprecated_option "with-python3" => "with-python"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "python@2" => :recommended if MacOS.version <= :snow_leopard
  depends_on "python" => :optional

  resource "six" do
    url "https://files.pythonhosted.org/packages/16/d8/bc6316cf98419719bd59c91742194c111b6f2e85abac88e496adefaf7afe/six-1.11.0.tar.gz"
    sha256 "70e8a77beed4562e7f14fe23a786b54f6296e34344c23bc42f07b15018ff98e9"
  end

  # Upstream's autogen script fetches this if not present
  # but does no integrity verification & mandates being online to install.
  resource "gmock" do
    url "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/googlemock/gmock-1.7.0.zip"
    mirror "https://dl.bintray.com/homebrew/mirror/gmock-1.7.0.zip"
    sha256 "26fcbb5925b74ad5fc8c26b0495dfc96353f4d553492eb97e85a8a6d2f43095b"
  end

  needs :cxx11

  def install
    # Reduce memory usage below 4 GB for Circle CI.
    ENV["MAKEFLAGS"] = "-j8" if ENV["CIRCLECI"]

    # Don't build in debug mode. See:
    # https://github.com/Homebrew/homebrew/issues/9279
    # https://github.com/google/protobuf/blob/5c24564811c08772d090305be36fae82d8f12bbe/configure.ac#L61
    ENV.prepend "CXXFLAGS", "-DNDEBUG"
    ENV.cxx11

    (buildpath/"gmock").install resource("gmock")
    system "./autogen.sh"

    system "./configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}", "--with-zlib"
    system "make"
    system "make", "check" if build.with?("test") || build.bottle?
    system "make", "install"

    # Install editor support and examples
    doc.install "editors", "examples"

    Language::Python.each_python(build) do |python, version|
      resource("six").stage do
        system python, *Language::Python.setup_install_args(libexec)
      end
      chdir "python" do
        ENV.append_to_cflags "-I#{include}"
        ENV.append_to_cflags "-L#{lib}"
        args = Language::Python.setup_install_args libexec
        args << "--cpp_implementation"
        system python, *args
      end
      site_packages = "lib/python#{version}/site-packages"
      pth_contents = "import site; site.addsitedir('#{libexec/site_packages}')\n"
      (prefix/site_packages/"homebrew-protobuf.pth").write pth_contents
    end
  end

  def caveats; <<~EOS
    Editor support and examples have been installed to:
      #{doc}
    EOS
  end

  test do
    testdata = <<~EOS
      syntax = "proto3";
      package test;
      message TestCase {
        string name = 4;
      }
      message Test {
        repeated TestCase case = 1;
      }
    EOS
    (testpath/"test.proto").write testdata
    system bin/"protoc", "test.proto", "--cpp_out=."
    system "python2.7", "-c", "import google.protobuf" if build.with? "python@2"
    system "python3", "-c", "import google.protobuf" if build.with? "python"
  end
end
