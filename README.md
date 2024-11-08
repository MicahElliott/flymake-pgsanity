# flymake-pgsanity and SQL linting beyond Emacs

Lint your SQL (and even funky templated SQL!) in Emacs with
[flymake](https://www.gnu.org/software/emacs/manual/html_node/flymake/index.html).
AFAIK this is the only implementation of an SQL linter for flymake (even
though it's very simple). Also included here is a recipe for running such
linters in CI (eg, Github Actions). And some bonus syntax highlighting tips.

This does not attempt to edit code -- just to _identify_ (with squiggly lines)
problems as you type them.

You'll need [ecpg](https://www.postgresql.org/docs/current/app-ecpg.html) for
any of this to work. It's broadly available via any package manager. And this
is PostgreSQL-only.

You'll also need Captain's [huglint](TODO) to make this work.

Historic note: this project used to depend on
[pgsanity](https://github.com/markdrago/pgsanity), but that dep was removed
when I determined that it was such a tiny (and buggy) wrapper around `ecpg`,
that I could replace any need for Python with one line of `sed`.

## Emacs linting

There are already similar SQL linters available for
[flycheck](https://www.flycheck.org/), but I've been trying to get everything
I use onto the built-in flymake.

To use with your Emacs, put `flymake-pgsanity.el` onto your load-path, and:

```lisp
;; (add-to-list 'load-path "~/.../vendor") ; wherever you keep non-melpa additions
(require 'flymake-pgsanity)
(add-hook 'sql-mode-hook 'flymake-pgsanity-setup)
```

Then freshly open a `.sql` file and it should start highlighting any errors.

If you want to use a different linter/script, _customize_
`flymake-pgsanity-program`. Eg, set it to `huglint` (after putting
[it](huglint) on your `path`) if you use Hug.

## SQL-like files (HugSQL, PugSQL, etc)

_(If you are only interested in editing/checking of straight SQL files, ignore
this section.)_

The whole reason I started this effort was for some silly mistakes I'd been
making in tweaking [HugSQL](https://www.hugsql.org/) `.sql` files. The errors
would have been immediately caught by a linter (instead of at runtime!), if
only there was one.

The trick is having a very simple preprocessor (`sed` one-liner script,
included) that can convert the special `:foo-bar` parameters into something
that a standard SQL linter can handle. I tried converting them all to basic
strings like `'foo-bar-XXX'` and it worked! Yes, it also supports those weird
params like `:v*:so-weird`.

The other necessary bits to make ecpg happy involve you manually
"improving" your Hug files:

- manually add semicolons (`;`) to the ends of each SQL statement, which
  ecpg needs and Hug doesn't mind

- don't end with a dangling `WHERE`

For that last case, here's an example:

```
problem:
WHERE
--~ (if ... "foo = :foo" "bar = :bar")

fix:
WHERE TRUE
--~ (if ... "AND foo = :foo" "AND bar = :bar")
```

## In CI

Here's a recipe for running ecpg in Github Actions. This installs the
dependency, [ecpg](https://www.postgresql.org/docs/current/app-ecpg.html), and
a custom [pgsanity-wrapper](pgsanity-ci.sh) linter (which you'll edit to suit
your needs) that will reject the build.

```yaml
jobs:
  checks:

    - name: Install ecpg Postgres FE
      run: |
        sudo apt-get install libecpg-dev
        
    ...

    - name: Check for any lint warnings/errors in sql files (ecpg)
      run: ./deploy/bin/pgsanity-ci.sh
```

## Emacs syntax highlighting

You can make your special `:foo-bar` params in SQL files stand out (bold blue)
with this:

```lisp
(defface sql-field '((t (:foreground "#528fd1" :weight ultra-bold))) "My SQL Field")
(font-lock-add-keywords 'sql-mode '((" :\\(v\\*:\\)?[-a-z0-9?]+"  0 'sql-field t)))

;; Other Hug goodies
(font-lock-add-keywords 'sql-mode '(("-- :doc .*" 0 'doc-field t)))
(font-lock-add-keywords 'sql-mode '(("-- :name [^:]+" 0 'special-comment t)))
(font-lock-add-keywords 'sql-mode '((" \\(:\\*\\|:!\\|:n\\|:\\?\\|:1\\)" 0 'boolean-true t)))
```

I suppose it'd be nice to color the _list_ (`:v*:...`) types differently.

## Hug in imenu

Neat way to see list of a hug file's functions in imenu:

```
(setq hug-imenu-generic-expression
      '(("SELECTS" "^-- :name \\([-a-z0-9?!]+\\) .*:\\?" 1)
        ("EXECS"   "^-- :name \\([-a-z0-9?!]+\\) .*:!" 1)
        ("INSERTS" "^-- :name \\([-a-z0-9?!]+\\) .*:i!" 1)))
(add-hook 'sql-mode-hook (lambda ()  (setq imenu-generic-expression
hug-imenu-generic-expression)))
```

Based simply on `:?` and `:!` as
[detailed here](https://www.hugsql.org/hugsql-in-detail/command).

Shown here with `[imenu-list-smart-toggle](https://github.com/bmag/imenu-list)`and `[consult-imenu](https://github.com/minad/consult)`.

This also got me realizing it's useful to organize hug files into something like those 3 sections.

## Other related/interesting projects

- [sqllint](https://github.com/purcell/sqlint) (awesome! but flycheck, not flymake)
- [sqlfluff](https://github.com/sqlfluff/sqlfluff)
- [sql-lint](https://github.com/joereynolds/sql-lint)
- [flymake-diagnostic-at-point](https://github.com/meqif/flymake-diagnostic-at-point)
- [captain](https://github.com/MicahElliott/captain) (for local git-hooking)
