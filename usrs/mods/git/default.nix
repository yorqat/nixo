{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [openssl pinentry-qt gitui ghq];

  programs.git = {
    enable = true;
    userName = "YorQat";
    userEmail = "qarkdev+gh@gmail.com";
    extraConfig = {
      init = {defaultBranch = "main";};
      delta = {
        # syntax-theme = "Nord";
        line-numbers = true;
      };

      # Sign commits
      # commit.gpgsign = true;
      gpg.format = "ssh";
      # gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      # user.signingkey = "~/.ssh/id_ed25519.pub";
    };
    lfs.enable = true;
    delta.enable = true;
  };

  programs.gh = {enable = true;};

  programs.gpg.enable = true;
}
