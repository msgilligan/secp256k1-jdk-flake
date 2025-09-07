{
inputs = {
    nixpkgs.url = "github:nixpkgs-jdk-ea/nixpkgs/jdk-ea-25";
};
outputs = {self, nixpkgs, ...}: {
  packages.aarch64-darwin.secp256k1-jdk = 
    let
      pkgs = nixpkgs.legacyPackages.aarch64-darwin.pkgs;

      gradle = pkgs.gradle.override {
        java = pkgs.jdk23_headless; # Run Gradle with this JDK
      };
      jre = pkgs.jdk23_headless;  # JRE to run the example with
      makeWrapper = pkgs.makeWrapper;
      secp256k1 = pkgs.secp256k1;
      version = "0.2-SNAPSHOT";

      self = pkgs.stdenv.mkDerivation (_finalAttrs: {
        inherit version;
        pname = "secp256k1-jdk";
        meta.mainProgram = "schnorr-example";

        src = pkgs.fetchFromGitHub {
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

        # TODO: The list of JARs in --module-path is hard-coded
        installPhase = ''
          mkdir -p $out/{bin,share/secp256k1-jdk/libs,share/secp-examples-java/libs}
          cp secp-api/build/libs/*.jar $out/share/secp256k1-jdk/libs
          cp secp-bouncy/build/libs/*.jar $out/share/secp256k1-jdk/libs
          cp secp-ffm/build/libs/*.jar $out/share/secp256k1-jdk/libs
          cp secp-examples-java/build/install/secp-examples-java/lib/*.jar $out/share/secp-examples-java/libs

          makeWrapper ${jre}/bin/java $out/bin/schnorr-example \
            --add-flags "--enable-native-access=org.bitcoinj.secp.ffm" \
            --add-flags "-Djava.library.path=${secp256k1}/lib" \
            --add-flags "--module-path $out/share/secp-examples-java/libs/jspecify-1.0.0.jar:$out/share/secp-examples-java/libs/secp-api-${version}.jar:$out/share/secp-examples-java/libs/secp-examples-java-${version}.jar:$out/share/secp-examples-java/libs/secp-ffm-${version}.jar" \
            --add-flags "--module org.bitcoinj.secp.examples/org.bitcoinj.secp.examples.Schnorr"
        '';
      });
    in
      self;
  packages.aarch64-darwin.secp256k1-jdk-native =
    let
      allowedUnfree = [ "graalvm-oracle" ]; # list of allowed unfree packages
      pkgs = import nixpkgs {
          system = "aarch64-darwin";
          config.allowUnfreePredicate = pkg:
            builtins.elem (pkgs.lib.getName pkg) allowedUnfree;
      };

      gradle = pkgs.gradle.override {
        java = pkgs.jdk24_headless; # Run Gradle with this JDK
      };
      makeWrapper = pkgs.makeWrapper;
      secp256k1 = pkgs.secp256k1;
      graalvm = pkgs.graalvmPackages.graalvm-oracle_25-ea;
      version = "0.2-SNAPSHOT";
      mainProgram = "schnorr-example-native";

      self = pkgs.stdenv.mkDerivation (_finalAttrs: {
        inherit version;
        pname = "secp256k1-jdk-native";
        meta.mainProgram = mainProgram;

        src = pkgs.fetchFromGitHub {
          owner = "bitcoinj";
          repo = "secp256k1-jdk";
          rev = "8f9746d7ab875b420a60b6e36234e20ea155927d"; # msgilligan/graaltest 25-08-08
          sha256 = "sha256-7trYb4hOAZSRnZxUrHGuiTNR9hbkXWsVYe7ggRCZa1s=";
        };

        nativeBuildInputs = [gradle makeWrapper secp256k1 graalvm];

        mitmCache = gradle.fetchDeps {
          pkg = self;
          # update or regenerate this by running
          #  $(nix build .#secp256k1-jdk-native.mitmCache.updateScript --print-out-paths)
          data = ./deps-native.json;
        };

        buildPhase = ''
          export GRAALVM_HOME=${graalvm}
          echo GRAALVM_HOME is $GRAALVM_HOME
          ${gradle}/bin/gradle -PjavaPath=${secp256k1}/lib  --info --stacktrace build secp-examples-java:nativeCompileSchnorr
        '';

        # will run the gradleCheckTask (defaults to "test")
        doCheck = false;

        installPhase = ''
          mkdir -p $out/bin
          cp secp-examples-java/build/schnorr-example $out/bin/${mainProgram}
          wrapProgram $out/bin/${mainProgram} --prefix DYLD_LIBRARY_PATH : "${pkgs.secp256k1}/lib"
        '';
      });
    in
      self;
  };
}
