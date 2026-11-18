// excerptgen は、上流（Try Omarchy for Windows の app/）の大きなファイルから、一覧に書いた宣言だけを
// そのまま抜き出して Go のファイルを作る。上流のコードをリポジトリに複製しないため、ビルド時に動かす。
//
//	go run ./tools/excerptgen <上流の app ディレクトリ> <一覧> <出力ディレクトリ>
//
// 一覧は 1 行に「上流のファイル名: 宣言の名前 ...」と書く（# 以降はコメント）。メソッドは「型.名前」。
// 上流のファイル F から抜き出した宣言は、出力ディレクトリの excerpt_F に、上流での順に書く。
//   - 関数・メソッドと、括弧の無い var / const / type は、直前のコメントごと上流のソースのまま書く。
//   - 括弧でまとめた var / const / type は、全部を選んだならまとめごと、一部なら選んだものだけを
//     同じ種類の括弧でまとめ直して書く。値を省いた（iota を引き継ぐ）const のまとめは一部だけ選べない。
//   - import は、上流のファイルの import のうち、抜き出した宣言が使うものだけを書く。
//   - 上流のファイルの //go:build の行を引き継ぐ。
// 一覧の名前が上流のそのファイルに無ければ失敗する。改変は、生成したファイルに patches/ のパッチで当てる。
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"go/ast"
	"go/format"
	"go/parser"
	"go/token"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

func main() {
	if len(os.Args) != 4 {
		fail("usage: excerptgen <upstream app dir> <list> <out dir>")
	}
	upDir, list, outDir := os.Args[1], os.Args[2], os.Args[3]
	wanted, order := readList(list)
	for _, file := range order {
		src, err := generate(filepath.Join(upDir, file), file, wanted[file])
		if err != nil {
			fail(err.Error())
		}
		if err := os.WriteFile(filepath.Join(outDir, "excerpt_"+file), src, 0o644); err != nil {
			fail(err.Error())
		}
	}
}

func fail(msg string) {
	fmt.Fprintln(os.Stderr, "excerptgen:", msg)
	os.Exit(1)
}

func readList(list string) (map[string]map[string]bool, []string) {
	f, err := os.Open(list)
	if err != nil {
		fail(err.Error())
	}
	defer f.Close()
	wanted := map[string]map[string]bool{}
	var order []string
	s := bufio.NewScanner(f)
	for n := 1; s.Scan(); n++ {
		line, _, _ := strings.Cut(s.Text(), "#")
		if strings.TrimSpace(line) == "" {
			continue
		}
		file, names, ok := strings.Cut(line, ":")
		file = strings.TrimSpace(file)
		if !ok || file == "" || strings.ContainsAny(file, `/\`) || !strings.HasSuffix(file, ".go") {
			fail(fmt.Sprintf("%s:%d: 「上流のファイル名: 宣言の名前 ...」の形ではない", list, n))
		}
		if wanted[file] == nil {
			wanted[file] = map[string]bool{}
			order = append(order, file)
		}
		for _, name := range strings.Fields(names) {
			if wanted[file][name] {
				fail(fmt.Sprintf("%s:%d: %s が重複している", list, n, name))
			}
			wanted[file][name] = true
		}
	}
	if err := s.Err(); err != nil {
		fail(err.Error())
	}
	return wanted, order
}

var buildLine = regexp.MustCompile(`(?m)^//go:build .*$`)

func generate(upPath, file string, wanted map[string]bool) ([]byte, error) {
	src, err := os.ReadFile(upPath)
	if err != nil {
		return nil, err
	}
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, upPath, src, parser.ParseComments)
	if err != nil {
		return nil, err
	}
	off := func(p token.Pos) int { return fset.Position(p).Offset }
	text := func(from, to token.Pos) string { return string(src[off(from):off(to)]) }
	// 行頭（字下げを含む）から書き出すため
	lineStart := func(p token.Pos) token.Pos {
		o := off(p)
		for o > 0 && src[o-1] != '\n' {
			o--
		}
		return p - token.Pos(off(p)-o)
	}

	found := map[string]bool{}
	var body strings.Builder
	var used []ast.Node
	for _, d := range f.Decls {
		switch d := d.(type) {
		case *ast.FuncDecl:
			name := d.Name.Name
			if d.Recv != nil && len(d.Recv.List) == 1 {
				name = recvName(d.Recv.List[0].Type) + "." + name
			}
			if !wanted[name] {
				continue
			}
			found[name] = true
			start := d.Pos()
			if d.Doc != nil {
				start = d.Doc.Pos()
			}
			body.WriteString(text(start, d.End()) + "\n\n")
			used = append(used, d)
		case *ast.GenDecl:
			if d.Tok == token.IMPORT {
				continue
			}
			var picked []ast.Spec
			for _, s := range d.Specs {
				names := specNames(s)
				any := false
				for _, n := range names {
					if wanted[n] {
						any = true
					}
				}
				if !any {
					continue
				}
				for _, n := range names {
					if !wanted[n] {
						return nil, fmt.Errorf("%s: %s は %s と同じ宣言なので一緒に一覧に書く", file, n, strings.Join(names, ", "))
					}
					found[n] = true
				}
				picked = append(picked, s)
			}
			if len(picked) == 0 {
				continue
			}
			for _, s := range picked {
				used = append(used, s)
			}
			start := d.Pos()
			if d.Doc != nil {
				start = d.Doc.Pos()
			}
			if len(picked) == len(d.Specs) {
				body.WriteString(text(start, declEnd(d)) + "\n\n")
				continue
			}
			if d.Tok == token.CONST {
				for _, s := range d.Specs {
					if len(s.(*ast.ValueSpec).Values) == 0 {
						return nil, fmt.Errorf("%s: 値を引き継ぐ const のまとめ（%s ほか）は一部だけ選べない", file, specNames(d.Specs[0])[0])
					}
				}
			}
			body.WriteString(text(start, d.Pos()) + d.Tok.String() + " (\n")
			for _, s := range picked {
				from := lineStart(s.Pos())
				if doc := specDoc(s); doc != nil {
					from = lineStart(doc.Pos())
				}
				body.WriteString(text(from, specEnd(d, s)) + "\n")
			}
			body.WriteString(")\n\n")
		}
	}

	var missing []string
	for n := range wanted {
		if !found[n] {
			missing = append(missing, n)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return nil, fmt.Errorf("%s に無い宣言: %s", file, strings.Join(missing, ", "))
	}

	refs := map[string]bool{}
	for _, n := range used {
		ast.Inspect(n, func(n ast.Node) bool {
			if sel, ok := n.(*ast.SelectorExpr); ok {
				if id, ok := sel.X.(*ast.Ident); ok {
					refs[id.Name] = true
				}
			}
			return true
		})
	}
	var imports []string
	for _, im := range f.Imports {
		p, _ := strconv.Unquote(im.Path.Value)
		name := importName(p)
		if im.Name != nil {
			name = im.Name.Name
		}
		if refs[name] {
			imports = append(imports, text(im.Pos(), im.End()))
		}
	}

	var out bytes.Buffer
	fmt.Fprintf(&out, "// Code generated by tools/excerptgen from app/%s of try-omarchy-windows; DO NOT EDIT.\n\n", file)
	if b := buildLine.Find(src[:off(f.Package)]); b != nil {
		out.Write(b)
		out.WriteString("\n\n")
	}
	out.WriteString("package " + f.Name.Name + "\n\n")
	if len(imports) > 0 {
		out.WriteString("import (\n\t" + strings.Join(imports, "\n\t") + "\n)\n\n")
	}
	out.WriteString(body.String())
	formatted, err := format.Source(out.Bytes())
	if err != nil {
		return nil, fmt.Errorf("%s: 生成したソースが不正: %v", file, err)
	}
	return formatted, nil
}

func specNames(s ast.Spec) []string {
	switch s := s.(type) {
	case *ast.TypeSpec:
		return []string{s.Name.Name}
	case *ast.ValueSpec:
		var names []string
		for _, n := range s.Names {
			names = append(names, n.Name)
		}
		return names
	}
	return nil
}

func specDoc(s ast.Spec) *ast.CommentGroup {
	switch s := s.(type) {
	case *ast.TypeSpec:
		return s.Doc
	case *ast.ValueSpec:
		return s.Doc
	}
	return nil
}

// specEnd は、仕様の行末のコメントまでを含む終わり。
func specEnd(d *ast.GenDecl, s ast.Spec) token.Pos {
	end := s.End()
	var c *ast.CommentGroup
	switch s := s.(type) {
	case *ast.TypeSpec:
		c = s.Comment
	case *ast.ValueSpec:
		c = s.Comment
	}
	if c != nil && c.End() > end {
		end = c.End()
	}
	return end
}

// declEnd は、宣言全体（括弧のまとめなら閉じ括弧、無ければ行末のコメント）までの終わり。
func declEnd(d *ast.GenDecl) token.Pos {
	end := d.End()
	if !d.Lparen.IsValid() {
		if e := specEnd(d, d.Specs[0]); e > end {
			end = e
		}
	}
	return end
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

// importName は import のパスからパッケージ名を決める（標準ライブラリだけを想定。末尾の /vN は飛ばす）。
func importName(p string) string {
	base := path.Base(p)
	if regexp.MustCompile(`^v[0-9]+$`).MatchString(base) {
		base = path.Base(path.Dir(p))
	}
	return base
}
