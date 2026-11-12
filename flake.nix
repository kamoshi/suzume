{
  description = "Suzume service";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = pkgs.lib;
          jre = pkgs.jdk21_headless;
        in
        {
          default = pkgs.maven.buildMavenPackage {
            pname = "suzume";
            version = "0.0.1-SNAPSHOT";

            src = lib.cleanSource ./.;

            mvnHash = "sha256-0zn/Pk7QBgaBD8MukL6VSeEU5fWTpQhTMwQ3YZ6sh/4=";

            nativeBuildInputs = [
              pkgs.makeWrapper
            ];

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/java

              install -Dm644 \
                target/suzume-0.0.1-SNAPSHOT.jar \
                $out/share/java/suzume.jar

              makeWrapper ${jre}/bin/java $out/bin/suzume \
                --add-flags "-jar $out/share/java/suzume.jar"

              runHook postInstall
            '';

            meta = {
              description = "Suzume REST API";
              mainProgram = "suzume";
            };
          };
        });
    in
    {
      inherit packages;

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.jdk21
              pkgs.maven
              pkgs.git
              pkgs.curl
            ];
          };
        });

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.suzume;
        in {
          options = {
            services.suzume = {
              enable = lib.mkEnableOption "Suzume";

              address = lib.mkOption {
                type = lib.types.str;
                default = "127.0.0.1";
                description = "Address on which Suzume listens";
              };

              port = lib.mkOption {
                type = lib.types.port;
                default = 8080;
                description = "Port on which Suzume listens.";
              };
            };
          };

          config = {
            systemd.services.suzume = {
              description = "Suzume";

              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];

              environment = {
                SPRING_PROFILES_ACTIVE = "prod";
                SERVER_ADDRESS = cfg.address;
                SERVER_PORT = toString cfg.port;
              };

              serviceConfig = {
                ExecStart = "${self.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/suzume";

                DynamicUser = true;
                StateDirectory = "suzume";
                WorkingDirectory = "/var/lib/suzume";

                EnvironmentFile = "-/etc/suzume/suzume.env";

                Restart = "on-failure";
                RestartSec = "5s";

                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
              };
            };
          };
        };
    };
}
