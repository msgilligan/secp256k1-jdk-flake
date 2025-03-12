{
inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
};
outputs = {self, nixpkgs, ...}: {
  packages.aarch64-darwin.secp256k1-jdk = 
    let
      pkgs = nixpkgs.legacyPackages.aarch64-darwin.pkgs;
      stdenv = pkgs.stdenv;
      fetchFromGitHub = pkgs.fetchFromGitHub;
      gradle = pkgs.gradle.override {
        java = pkgs.jdk23_headless; # Run Gradle with this JDK
      };
      jre = pkgs.jdk23_headless;  # JRE to run the example with
      makeWrapper = pkgs.makeWrapper;
      secp256k1 = pkgs.secp256k1;
      self = stdenv.mkDerivation (_finalAttrs: {
        pname = "secp256k1-jdk";
        version = "0.2-unstable";

        src = fetchFromGitHub {
          owner = "bitcoinj";
          repo = "secp256k1-jdk";
          rev = "3aa410ee785acc6483468a8b294161f915fbfe65";
          sha256 = "sha256-kxJ4FaZiCpznioK3/OYf34jQv1/FNKJntKbyHuBCI4M=";
        };

        nativeBuildInputs = [gradle makeWrapper secp256k1];

        mitmCache = gradle.fetchDeps {
          pkg = self;
          # update or regenerate this by running
          #  $(nix build .#secp256k1-jdk.mitmCache.updateScript --print-out-paths)
          data = ./deps.json;
        };

        # defaults to "assemble"
        gradleBuildTask = "secp-examples-java:installDist";

        gradleFlags = [ "-PjavaPath=${secp256k1}/lib  --info --stacktrace" ];

        # will run the gradleCheckTask (defaults to "test")
        doCheck = false;

        # TODO:  0.2-SNAPSHOT is currently hardcoded in the path to the JARs
        # TODO: The list of JARs is also hard-coded
        installPhase = ''
          mkdir -p $out/{bin,share/secp256k1-jdk/libs,share/secp-examples-java/libs}
          cp secp-api/build/libs/*.jar $out/share/secp256k1-jdk/libs
          cp secp-bouncy/build/libs/*.jar $out/share/secp256k1-jdk/libs
          cp secp-ffm/build/libs/*.jar $out/share/secp256k1-jdk/libs
          cp secp-examples-java/build/install/secp-examples-java/lib/*.jar $out/share/secp-examples-java/libs

          makeWrapper ${jre}/bin/java $out/bin/schnorr-example \
            --add-flags "--enable-native-access=org.bitcoinj.secp.ffm" \
            --add-flags "-Djava.library.path=${secp256k1}/lib" \
            --add-flags "--module-path $out/share/secp-examples-java/libs/jspecify-1.0.0.jar:$out/share/secp-examples-java/libs/secp-api-0.2-SNAPSHOT.jar:$out/share/secp-examples-java/libs/secp-examples-java-0.2-SNAPSHOT.jar:$out/share/secp-examples-java/libs/secp-ffm-0.2-SNAPSHOT.jar" \
            --add-flags "--module org.bitcoinj.secp.examples/org.bitcoinj.secp.examples.Schnorr"
        '';
      });
    in
      self;
  };
}
