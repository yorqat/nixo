{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [openssl pinentry-qt gitui ghq];

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;

    signing = {
      format = null;
    };

    settings = {
      user = { 
        name = "YorQat";
        email = "qarkdev+gh@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };

      # Sign commits
      # commit.gpgsign = true;
      gpg.format = "ssh";
      # gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      # user.signingkey = "~/.ssh/id_ed25519.pub";
    };

    lfs.enable = true;
  };

  programs.gh = {enable = true;};

  programs.gpg.enable = true;
}
