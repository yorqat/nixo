{...}: {
  # conservative start: whole trees persist, root is blank at boot.
  # phase 3 tightens this to per-app enumeration.
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc"
      "/var"
      "/home"
      "/root"
    ];
  };
}
