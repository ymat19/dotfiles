{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;
    delta.enable = true;
    userName = "ymat19";
    userEmail = "ymat19@example.com";
    ignores = [ ".direnv/" ];
  };

  home.packages = lib.mkAfter (with pkgs; [
    ghq
    git-lfs
  ]);

  programs.zsh.initExtra = lib.mkAfter ''
    # https://qiita.com/tomoyamachi/items/e51d2906a5bb24cf1684
    function ghq-fzf() {
      local src=$(ghq list -p | fzf --preview "bat --color=always --style=header,grid --line-range :80 {}/README.*")
      if [ -n "$src" ]; then
        BUFFER="cd $src"
        zle accept-line
      fi
      zle -R -c
    }
    zle -N ghq-fzf
    bindkey '^]' ghq-fzf

    function fsw() {
      # worktree listから末端ディレクトリ名のみを抽出してリスト表示
      local branch_name=$(git worktree list | awk '{print $1}' | xargs -I {} basename {} | fzf --preview 'branch_with_slash=$(echo {} | sed "s/-/\//g"); git log --oneline -10 "$branch_with_slash"')
      
      # 選択がキャンセルされた場合は終了
      if [ -z "$branch_name" ]; then
        return 1
      fi
      
      # git worktree listから選択されたブランチ名にマッチするパスを取得
      local worktree_path=$(git worktree list | awk -v branch_name="$branch_name" '{if (system("[ \"$(basename \"" $1 "\")\" = \"" branch_name "\" ]") == 0) print $1}')
      
      echo "Moving to worktree: $worktree_path"
      cd "$worktree_path"
    }

    function fcw() {
      # ローカル・リモート全ブランチを取得（ローカルに(local)プレフィックス）
      local branch=$(
        {
          git branch --format="(local) %(refname:short)"
          git branch -r --format="%(refname:short)" | sed 's/^origin\///' | grep -v '^origin$'
        } | sort -u | fzf --preview 'branch=$(echo {} | sed "s/^(local) //"); git log --oneline -10 "$branch"'
      )
      
      # 選択がキャンセルされた場合は終了
      if [ -z "$branch" ]; then
        return 1
      fi
      
      # (local)プレフィックスを除去
      branch=$(echo "$branch" | sed "s/^(local) //")
      
      # worktreeパスを構築（ネストした構造）
      local repo_name=$(basename $(pwd))
      local safe_branch=$(echo "$branch" | sed 's/\//-/g')
      local worktree_path="$HOME/worktrees/$repo_name/$safe_branch"
      
      # 親ディレクトリ作成
      mkdir -p "$HOME/worktrees/$repo_name"
      
      # worktree作成
      echo "Creating new worktree: $worktree_path"
      git worktree add "$worktree_path" "$branch" && cd "$worktree_path"
    }

    function frw() {
      # worktree listから末端ディレクトリ名のみを抽出してリスト表示（メインディレクトリを除外）
      local branch_name=$(git worktree list | tail -n +2 | awk '{print $1}' | xargs -I {} basename {} | fzf --preview 'branch_with_slash=$(echo {} | sed "s/-/\//g"); git log --oneline -10 "$branch_with_slash"')
      
      # 選択がキャンセルされた場合は終了
      if [ -z "$branch_name" ]; then
        return 1
      fi
      
      # git worktree listから選択されたブランチ名にマッチするパスを取得
      local worktree_path=$(git worktree list | awk -v branch_name="$branch_name" '{if (system("[ \"$(basename \"" $1 "\")\" = \"" branch_name "\" ]") == 0) print $1}')
      
      # 確認メッセージ
      echo "Removing worktree: $worktree_path"
      read -q "REPLY?Are you sure? (y/N): "
      echo
      
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        git worktree remove "$worktree_path"
        echo "Worktree removed: $worktree_path"
      else
        echo "Cancelled"
      fi
    }

  '';
}
