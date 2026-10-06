{
  pkgs,
  setup,
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

    # Conditional routing for GitLab: repos under setup.git.work.dir commit as a
    # different address than the global one. ~/ is kept in the pattern because
    # that is the form git matches `gitdir:` against.
    includes = [
      {
        condition = "gitdir:~/${setup.git.work.dir}/**";
        contents.user.email = setup.git.work.email;
      }
    ];

    settings = {
      user = {
        name = setup.git.name;
        email = setup.git.email;
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
