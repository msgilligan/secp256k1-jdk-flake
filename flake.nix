{
inputs = {
    nixpkgs.url = "github:nixpkgs-jdk-ea/nixpkgs/jdk-ea-25";
};
outputs = {self, nixpkgs, ...}: {
  packages.aarch64-darwin.secp256k1-jdk = 
    let
      allowedUnfree = [ "graalvm-oracle" ]; # list of allowed unfree packages
      pkgs = import nixpkgs {
          system = "aarch64-darwin";
          config.allowUnfreePredicate = pkg:
            builtins.elem (pkgs.lib.getName pkg) allowedUnfree;
      };

      gradle = pkgs.gradle_9.override {
        java = pkgs.graalvmPackages.graalvm-oracle_25-ea; # Run Gradle with this JDK
      };
      jre = pkgs.graalvmPackages.graalvm-oracle_25-ea;  # JRE to run the example with
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
          rev = "f0186ff23194d52cf507949d2d30d811a470e5a7"; # master 25-09-07
          sha256 = "sha256-dWzTgmMTwcwQaBXskhA9u2sU024SgkbsFsdFQdld6Vc=";
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
          mkdir -p $out/{bin,share/secp256k1-jdk/libs,share/schnorr-example/libs}
          cp secp-api/build/libs/*.jar $out/share/secp256k1-jdk/libs
          cp secp-bouncy/build/libs/*.jar $out/share/secp256k1-jdk/libs
          cp secp-ffm/build/libs/*.jar $out/share/secp256k1-jdk/libs
          cp secp-examples-java/build/install/schnorr-example/lib/*.jar $out/share/schnorr-example/libs

          makeWrapper ${jre}/bin/java $out/bin/schnorr-example \
            --add-flags "--enable-native-access=org.bitcoinj.secp.ffm" \
            --add-flags "-Djava.library.path=${secp256k1}/lib" \
            --add-flags "--module-path $out/share/schnorr-example/libs/jspecify-1.0.0.jar:$out/share/schnorr-example/libs/nativeimage-24.0.0.jar:$out/share/schnorr-example/libs/word-24.0.0.jar:$out/share/schnorr-example/libs/secp-api-${version}.jar:$out/share/schnorr-example/libs/secp-examples-java-${version}.jar:$out/share/schnorr-example/libs/secp-ffm-${version}.jar:$out/share/schnorr-example/libs/secp-graalvm-${version}.jar" \
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

      graalvm = pkgs.graalvmPackages.graalvm-oracle_25-ea;
      gradle = pkgs.gradle_9.override {
        java = graalvm; # Run Gradle with this JDK
      };
      makeWrapper = pkgs.makeWrapper;
      secp256k1 = pkgs.secp256k1;
      version = "0.2-SNAPSHOT";
      mainProgram = "schnorr-example-native";

      self = pkgs.stdenv.mkDerivation (_finalAttrs: {
        inherit version;
        pname = "secp256k1-jdk-native";
        meta.mainProgram = mainProgram;

        src = pkgs.fetchFromGitHub {
          owner = "bitcoinj";
          repo = "secp256k1-jdk";
          rev = "f0186ff23194d52cf507949d2d30d811a470e5a7"; # master 25-09-07
          sha256 = "sha256-dWzTgmMTwcwQaBXskhA9u2sU024SgkbsFsdFQdld6Vc=";
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
          export JAVA_TOOL_OPTIONS=-Djava.library.path=${secp256k1}/lib
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
