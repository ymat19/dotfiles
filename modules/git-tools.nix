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

    function fuzzy_switch_worktree() {
      # パイプ区切りの文字列リストを変数に保存
      local worktree_data=$(git worktree list | awk '{print $1}' | awk -F'/' '{print $NF"|"$0}')
      
      # パイプ以前だけをfzfに渡す
      local branch_name=$(echo "$worktree_data" | cut -d'|' -f1 | fzf --preview 'echo "Directory: {}"; git log --oneline -10 HEAD 2>/dev/null || echo "No git log available"')
      
      # 選択がキャンセルされた場合は終了
      if [ -z "$branch_name" ]; then
        return 1
      fi
      
      # 保存したリストから選択されたブランチ名にマッチする行を見つけてパスを抽出
      local worktree_path=$(echo "$worktree_data" | grep "^$branch_name|" | cut -d'|' -f2)
      
      echo "Moving to worktree: $worktree_path"
      cd "$worktree_path"
    }

    function fuzzy_create_worktree() {
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

    function fuzzy_remove_worktree() {
      # パイプ区切りの文字列リストを変数に保存（メインディレクトリを除外）
      local worktree_data=$(git worktree list | tail -n +2 | awk '{print $1}' | awk -F'/' '{print $NF"|"$0}')
      
      # パイプ以前だけをfzfに渡す
      local branch_name=$(echo "$worktree_data" | cut -d'|' -f1 | fzf --preview 'echo "Directory: {}"; git log --oneline -10 HEAD 2>/dev/null || echo "No git log available"')
      
      # 選択がキャンセルされた場合は終了
      if [ -z "$branch_name" ]; then
        return 1
      fi
      
      # 保存したリストから選択されたブランチ名にマッチする行を見つけてパスを抽出
      local worktree_path=$(echo "$worktree_data" | grep "^$branch_name|" | cut -d'|' -f2)
      
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

    function git_worktree_menu() {
      echo "Git Worktree Management"
      echo "c: Create | s: Switch | r: Remove"
      echo -n "Choose option (c/s/r): "
      read -k1 choice
      echo
      
      case $choice in
        c) fuzzy_create_worktree ;;
        s) fuzzy_switch_worktree ;;
        r) fuzzy_remove_worktree ;;
        *) echo "Invalid choice" ;;
      esac
    }
    zle -N git_worktree_menu
    bindkey '^G' git_worktree_menu

  '';
}
