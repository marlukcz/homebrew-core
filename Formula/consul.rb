class Consul < Formula
  desc "Tool for service discovery, monitoring and configuration"
  homepage "https://www.consul.io"
  url "https://github.com/hashicorp/consul.git",
      :tag => "v1.0.6",
      :revision => "9a494b5fb9c86180a5702e29c485df1507a47198"

  head "https://github.com/hashicorp/consul.git",
       :shallow => false

  bottle do
    cellar :any_skip_relocation
    rebuild 1
    sha256 "426227ee114e91f2560c141722d7b31a148b507a7617485ff1482f8b30f386c3" => :high_sierra
    sha256 "3154593fd96aa3efd6f2f0c9ca2aa8d1e13685e106a8cebdb5ea55a14e46662c" => :sierra
    sha256 "aa9f709a5d4a1042584b2f332848e30a62f3e909123fdbfdc6feac033d230ef0" => :el_capitan
    sha256 "d68eb77eccf300d7b47d4e663d484f892db3061ecf7f807e44d2fe3cf0a62dd1" => :x86_64_linux
  end

  depends_on "go" => :build
  depends_on "gox" => :build
  depends_on "zip" => :build unless OS.mac?

  def install
    # Reduce memory usage below 4 GB for Circle CI.
    inreplace "scripts/build.sh", "-tags=\"${GOTAGS}\" \\", "-tags=\"${GOTAGS}\" -parallel=4 \\"

    # Avoid running `go get`
    inreplace "GNUmakefile", "go get -u -v $(GOTOOLS)", ""

    ENV["XC_OS"] = OS.mac? ? "darwin" : "linux"
    ENV["XC_ARCH"] = MacOS.prefer_64_bit? ? "amd64" : "386" if OS.mac?
    ENV["XC_ARCH"] = "amd64" unless OS.mac?
    ENV["GOPATH"] = buildpath
    contents = Dir["{*,.git,.gitignore}"]
    (buildpath/"src/github.com/hashicorp/consul").install contents

    (buildpath/"bin").mkpath

    cd "src/github.com/hashicorp/consul" do
      system "make"
      bin.install "bin/consul"
      prefix.install_metafiles
    end
  end

  plist_options :manual => "consul agent -dev -advertise 127.0.0.1"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <dict>
          <key>SuccessfulExit</key>
          <false/>
        </dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/consul</string>
          <string>agent</string>
          <string>-dev</string>
          <string>-advertise</string>
          <string>127.0.0.1</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>WorkingDirectory</key>
        <string>#{var}</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/consul.log</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/consul.log</string>
      </dict>
    </plist>
    EOS
  end

  test do
    # Workaround for Error creating agent: Failed to get advertise address: Multiple private IPs found. Please configure one.
    return if ENV["CIRCLECI"] || ENV["TRAVIS"]

    fork do
      exec "#{bin}/consul", "agent", "-data-dir", "."
    end
    sleep 3
    system "#{bin}/consul", "leave"
  end
end
