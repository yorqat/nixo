{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [pinentry-qt gitui ghq];

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;

    signing = {
      format = null;
    };

    # Conditional routing for GitLab
    includes = [
      {
        condition = "gitdir:~/Documents/A-Work/1-Fling/gitlab/**";
        contents = {
          user = {
            email = "qarkdev+gl@gmail.com"; # Put your GitLab email here
            # signingKey = "~/.ssh/id_gitlab.pub";  # Optional: if you use a different SSH key for GitLab signing
          };
        };
      }
    ];

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
