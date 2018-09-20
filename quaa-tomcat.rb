class QuaaTomcat < Formula
  desc "Cloud Foundry UAA running inside Apache Tomcat"
  homepage "https://github.com/cloudfoundry/uaa"

  v = "v4.20.0" # CI Managed
  # remove v from version number
  verNum = v.sub "v", ""
  url "https://github.com/starkandwayne/uaa-war-releases/releases/download/v#{verNum}/cloudfoundry-identity-uaa-#{verNum}.war"
  version v
  sha256 "373036b0135fb27ffc9475c1b53bcf160a984cf17d145013862a3cc8248829e1"

  depends_on :java => "1.8+"
  depends_on "cloudfoundry/tap/bosh-cli" => "5.2.2"
  depends_on "starkandwayne/cf/uaa-cli" => "0.0.1"

  resource "tomcat" do
    url "https://www.apache.org/dyn/closer.cgi?path=/tomcat/tomcat-9/v9.0.12/bin/apache-tomcat-9.0.12.tar.gz"
    sha256 "1fa3d15dcbe7b1addf03cab39b27908b9e5bc3a26ab0c268c0abcc88920f51dc"
  end

  resource "manifests" do
    url "https://github.com/starkandwayne/quick-uaa-local.git", using: :git
  end

  def install
    warfile = Dir['*.war'].first
    prefix.install resource("manifests")
    FileUtils.mkdir_p "#{prefix}/operators"
    FileUtils.cp "#{prefix}/manifests/ops-files/3-http-only.yml", "#{prefix}/operators/3-http-only.yml"
    FileUtils.rm_rf "#{prefix}/.envrc"

    resource("tomcat").stage do
      puts "Installing Apache Tomcat..."
      libexec.install Dir["*"]
      bin.install_symlink "#{libexec}/bin/catalina.sh" => "uaa-catalina"
    end

  end

  # plist_options :manual => "uaa-catalina run"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Disabled</key>
        <false/>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/quaa</string>
          <string>up</string>
        </array>
        <key>KeepAlive</key>
        <true/>
        <key>EnvironmentVariables</key>
        <dict>
          <key>UAADEPLOY_PROJECT_ROOT</key>
          <string>#{prefix}</string>
          <key>CATALINA_BIN</key>
          <string>uaa-catalina</string>
          <key>OPTIONAL_CLI_INSTALL</key>
          <string>1</string>
        </dict>
        <key>StandardOutPath</key>
        <string>#{libexec}/logs/launchd.out.log</string>
        <key>StandardErrorPath</key>
        <string>#{libexec}/logs/launchd.err.log</string>
      </dict>
    </plist>
  EOS
  end

  test do
    ENV["CATALINA_BASE"] = testpath
    cp_r Dir["#{libexec}/*"], testpath
    rm Dir["#{libexec}/logs/*"]

    pid = fork do
      exec bin/"uaa-catalina", "start"
    end
    sleep 3
    begin
      system bin/"uaa-catalina", "stop"
    ensure
      Process.wait pid
    end
    assert_predicate testpath/"logs/catalina.out", :exist?
  end
end
