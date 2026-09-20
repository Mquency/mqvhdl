class Mqvhdl < Formula
  desc "Lightweight VHDL project workflow tool built around GHDL and GTKWave"
  homepage "https://github.com/mquency/mqvhdl"
  url "https://github.com/mquency/mqvhdl/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "REPLACE_WITH_TARBALL_SHA256" # shasum -a 256 <tarball>
  license "MIT"

  # mqvhdl needs bash >= 4.2; macOS /bin/bash is 3.2
  depends_on "bash"
  depends_on "ghdl"
  depends_on "gtkwave"

  def install
    bin.install "mqvhdl"
    doc.install "README.md"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mqvhdl --version")
  end
end
