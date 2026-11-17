// excerptcheck は、上流（Try Omarchy for Windows の app/）から抜き出した宣言が、上流の同名の宣言と
// 一致しているかを確かめる。上流を新しいコミットに上げたときに、抜き出しが古いまま残るのを防ぐ。
//
//	go run ./tools/excerptcheck <上流の app ディレクトリ> <抜き出しのファイル>...
//
// 照合しない宣言には、直前のコメントに次の印を付ける:
//
//	winq:modified  上流から改変したもの（理由をコメントに書く）
//	winq:new       上流に無い、自分で書いたもの
package main

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/parser"
	"go/printer"
	"go/token"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: excerptcheck <upstream app dir> <file>...")
		os.Exit(2)
	}
	upstream := decls(mustGlob(filepath.Join(os.Args[1], "*.go")), false)
	failed := false
	for _, file := range os.Args[2:] {
		for name, d := range decls([]string{file}, true) {
			if d.mark != "" {
				continue
			}
			u, ok := upstream[name]
			if !ok {
				fmt.Printf("%s: %s は上流に無い（自分で書いたものなら winq:new を付ける）\n", file, name)
				failed = true
			} else if u.src != d.src {
				fmt.Printf("%s: %s が上流（%s）と一致しない（改変したなら winq:modified を付ける）\n", file, name, u.file)
				failed = true
			}
		}
	}
	if failed {
		os.Exit(1)
	}
}

type decl struct{ file, src, mark string }

func mustGlob(pattern string) []string {
	files, err := filepath.Glob(pattern)
	if err != nil || len(files) == 0 {
		fmt.Fprintln(os.Stderr, "no files:", pattern)
		os.Exit(2)
	}
	var out []string
	for _, f := range files {
		if !strings.HasSuffix(f, "_test.go") {
			out = append(out, f)
		}
	}
	sort.Strings(out)
	return out
}

// decls は、各ファイルのトップレベルの宣言を「名前 → コメントを除いた整形済みのソース」にする。
// var / const / type のまとまりは、中の名前ごとに分ける。メソッドは「型.名前」にする。
func decls(files []string, marks bool) map[string]decl {
	out := map[string]decl{}
	fset := token.NewFileSet()
	for _, file := range files {
		f, err := parser.ParseFile(fset, file, nil, parser.ParseComments)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(2)
		}
		for _, d := range f.Decls {
			switch d := d.(type) {
			case *ast.FuncDecl:
				name := d.Name.Name
				if d.Recv != nil && len(d.Recv.List) == 1 {
					name = recvName(d.Recv.List[0].Type) + "." + name
				}
				mark := ""
				if marks {
					mark = markOf(d.Doc)
				}
				d.Doc = nil
				out[name] = decl{file, render(fset, d), mark}
			case *ast.GenDecl:
				groupMark := ""
				if marks {
					groupMark = markOf(d.Doc)
				}
				for _, s := range d.Specs {
					mark := groupMark
					var names []string
					switch s := s.(type) {
					case *ast.TypeSpec:
						names = []string{s.Name.Name}
						if marks && mark == "" {
							mark = markOf(s.Doc)
						}
						s.Doc, s.Comment = nil, nil
					case *ast.ValueSpec:
						for _, n := range s.Names {
							names = append(names, n.Name)
						}
						if marks && mark == "" {
							mark = markOf(s.Doc)
						}
						s.Doc, s.Comment = nil, nil
					case *ast.ImportSpec:
						continue
					}
					src := d.Tok.String() + " " + render(fset, s)
					for _, n := range names {
						out[n] = decl{file, src, mark}
					}
				}
			}
		}
	}
	return out
}

func recvName(e ast.Expr) string {
	switch t := e.(type) {
	case *ast.StarExpr:
		return recvName(t.X)
	case *ast.Ident:
		return t.Name
	case *ast.IndexExpr:
		return recvName(t.X)
	}
	return "?"
}

func markOf(g *ast.CommentGroup) string {
	if g == nil {
		return ""
	}
	for _, c := range g.List {
		for _, m := range []string{"winq:modified", "winq:new"} {
			if strings.Contains(c.Text, m) {
				return m
			}
		}
	}
	return ""
}

// render はコメントを含めずに整形する（ノードだけを渡すとコメントは出力されない）。
func render(fset *token.FileSet, n ast.Node) string {
	var b bytes.Buffer
	printer.Fprint(&b, fset, n)
	return b.String()
}
