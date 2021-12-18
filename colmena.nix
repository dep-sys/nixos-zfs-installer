{ lib }: let
  attrsFromFiles = dir: suffix: callback:
    lib.pipe
      (builtins.readDir dir)
      [
        (entry: lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix suffix n) entry)
        lib.attrNames
        (map (name:
          lib.nameValuePair
            (lib.strings.removeSuffix suffix name)
            (callback (dir + "/${name}"))))
        builtins.listToAttrs
      ];

  loadHostsJSON = attrsFromFiles
    ./hosts
    ".json"
    (filename: builtins.fromJSON (builtins.readFile filename));

  loadHostsNix = attrsFromFiles
    ./hosts
    ".nix"
    (filename: import filename);

in {

  makeColmenaHost = { runtimeInfo, profile }:
    {
      inherit runtimeInfo;
      profile.imports = [
        {
          deployment.targetHost = runtimeInfo.ipv6.address;
        }
        profile
      ];
    };

  makeColmenaHosts = callback:
    let
      profiles = loadHostsNix;
    in
      lib.mapAttrs (host: runtimeInfo:
        callback {
          inherit runtimeInfo;
          profile = (builtins.trace profiles (profiles.${host}));
        }
      ) loadHostsJSON;
}
