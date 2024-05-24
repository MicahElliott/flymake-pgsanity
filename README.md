# flymake-pgsanity and sql linting beyond Emacs

Lint your SQL (and even funky templated SQL!) in Emacs with
[flymake](https://www.gnu.org/software/emacs/manual/html_node/flymake/index.html).
AFAIK this is the only implementation of an SQL linter for flymake (even
though it's very simple). Also included here is a recipe for running such
linters in CI (eg, Github Actions). And some bonus syntax highlighting tips.

This does not attempt to edit code -- just to _identify_ (with squiggly lines)
problems as you type them.

You'll need [pgsanity](https://github.com/markdrago/pgsanity) for any of this
to work. It's broadly available via any package manager. And this is
PostgreSQL-only.

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
`flymake-pgsanity-program`. Eg, set it to `hugslint` (after putting
[it](hugslint) on your `path`) if you use Hugs.

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

The other necessary bits to make pgsanity happy involve you manually
"improving" your Hugs files:

- manually add semicolons (`;`) to the ends of each SQL statement, which
  pgsanity needs and Hugs doesn't mind

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

Here's a recipe for running pgsanity in Github Actions. This installs the
dependencies, [ecpg](https://www.postgresql.org/docs/current/app-ecpg.html)
and [pgsanity](https://github.com/markdrago/pgsanity), and a custom
[pgsanity-wrapper](pgsanity-ci.sh) linter (which you'll edit to suit your
needs) that will reject the build.

```yaml
jobs:
  checks:

    - name: Install ecpg Postgres FE and pgsanity SQL linter
      run: |
        sudo apt-get install libecpg-dev
        sudo pip install pgsanity

    ...

    - name: Check for any lint warnings/errors in sql files (pgsanity)
      run: ./deploy/bin/pgsanity-ci.sh
```

## Emacs syntax highlighting

You can make your special `:foo-bar` params in SQL files stand out (bold blue)
with this:

```lisp
(defface sql-field '((t (:foreground "#528fd1" :weight ultra-bold))) "My SQL Field")
(font-lock-add-keywords 'sql-mode '((" :\\(v\\*:\\)?[-a-z0-9?]+"  0 'sql-field t)))

;; Other Hugs goodies
(font-lock-add-keywords 'sql-mode '(("-- :doc .*" 0 'doc-field t)))
(font-lock-add-keywords 'sql-mode '(("-- :name [^:]+" 0 'special-comment t)))
(font-lock-add-keywords 'sql-mode '((" \\(:\\*\\|:!\\|:n\\|:\\?\\|:1\\)" 0 'boolean-true t)))
```

I suppose it'd be nice to color the _list_ (`:v*:...`) types differently.

## Other related/interesting projects

- [sqllint](https://github.com/purcell/sqlint) (awesome! but flycheck, not flymake)
- [sqlfluff](https://github.com/sqlfluff/sqlfluff)
- [sql-lint](https://github.com/joereynolds/sql-lint)
