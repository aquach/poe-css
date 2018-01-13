# PoE CSS

A better way to write item filters for Path of Exile.

Example:

```
@black: RGB(0, 0, 0)
@white: RGB(255, 255, 255)

@t1-gem-text-color: RGB(30, 200, 200)
@t1-gem-border-color: RGB(30, 150, 180)
@t1-gem-bg-color: @white

@volume: 300
@t1-drop-sound: 6 @volume
@unique-drop-sound: 3 @volume
@value-drop-sound: 2 @volume

@gem-styling() {
  SetTextColor @t1-gem-text-color
  SetBorderColor @t1-gem-border-color
}

Class Gems {
  Hide
  SetFontSize 36
  SetBorderColor @black

  Quality >= 1 {
    Show
    SetFontSize 40
    SetBorderColor @t1-gem-border-color
  }

  BaseType "Detonate Mines" "Added Chaos Damage" "Vaal" "Enhance" | Quality >= 14 {
    Show
    SetFontSize 40
    @gem-styling()
    PlayAlertSound @value-drop-sound
  }

  BaseType "Portal" "Empower" "Enlighten" "Vaal Haste" "Vaal Grace" "Item Quantity" "Vaal Breach" {
    Show
    SetFontSize 45
    @gem-styling()
    PlayAlertSound @unique-drop-sound
  }
}
```

Via the website or the command line tool, filters written in PoE CSS can be
transpiled into the native item filter language and plugged right into Path of
Exile.

### Features

* CSS-style semantics: multiple clauses can match any item, rather than just the first match in the base filter language.
* Constants
* Macro expansion
* Nested and OR matches

## Getting Started

`poe-css` is available online at LINK and as a command line utility. Both
transform PoE CSS filters into standard item filters that can be plugged into
Path of Exile. **PoE CSS filters are not directly compatible with Path of Exile**.
Below are instructions for installing the command line tool.

## Syntax

It's likely easiest to get a sense of the syntax by looking at the example
above. It should be familiar to anyone comfortable with Path of Exile's item
filter language as well as people comfortable with CSS/LESS/SASS.

First, everything in PoE CSS is case-insensitive.

A PoE CSS file is a list of clauses. A clause generally looks like this:

```
<list of matches, comma separated> {
  <commands>
}
```

For example,

```
ItemLevel >= 25 {
  Show
  SetFontSize 16
}
```

This clause will style any item whose item level is greater than or equal to
25. To see all possible conditions and styles, check out the [item filter
wiki](https://pathofexile.gamepedia.com/Item_filter). It's missing a few new
matches like ShapedItem though.

**To combine conditions so that all must match, use a comma**:

```
ItemLevel >= 25, Rarity Unique {
  Show
  SetFontSize 24
}
```

**Differently from the base item filter language, multiple clauses can match any
item, just like CSS.** To get an item's final style, PoE CSS finds all clauses
that match the given item, then combines all of their respective styles. Later
properties override earlier properties, so later clauses are generally more powerful than earlier clauses.

```
ItemLevel >= 25 {
  Show
  SetFontSize 25
  SetBackgroundColor RGB(0, 255, 0)
}

Rarity Unique {
  Show
  SetBackgroundColor RGB(255, 0, 0)
}
```

ilvl >= 25 items that are not unique will have the font size change and a green
background. Unique items will have a red background. ilvl >= 25 items that are
also unique will have the font size change and a red background.

This solves a common pain point with item filters, which is that adding new
clauses is very difficult and often accidentally overrides later styles.

To match one of many conditions (OR), **use `|`**:

```
ItemLevel >= 25 | Rarity Unique {
  Show
  SetFontSize 24
}
```

This is identical to writing it out long form.

```
ItemLevel >= 25 {
  Show
  SetFontSize 24
}

Rarity Unique {
  Show
  SetFontSize 24
}
```

**Nested clauses** are considered to be restrictions on the parent clause.

```
ItemLevel >= 25 {
  Show
  SetFontSize 24

  Rarity Unique {
    Show
    SetBackgroundColor RGB(255, 0, 0)
  }
}
```

In this filter, items with ilvl >= 25 will have font size 24, and items with ilvl >= 25 and are unique will have a red background color.

Nested clauses are useful when you'd like to work within a certain constraint without repeating yourself.

```
Class "Bows" {
  # All clauses in here will only match bows.

  Show

  ItemLevel >= 65 { SetFontSize 13 }
  ItemLevel >= 70 { SetFontSize 14 }
  ItemLevel >= 75 { SetFontSize 15 }
}
```

You can **define a constant with `@`**. Constants can only be defined once.

```
@rare-color: RGB(255, 255, 119)

Rarity Rare {
  SetFontColor @rare-color
}
```

Constants are substituted with naive string substitution. This means anything can be made a constant.

```
@sfc: SetFontColor

Rarity Rare {
  @sfc RGB(255, 0, 0)
}
```

**For multi-line substitutions or substitutions with variables, you can define macros.**

```
@ilvl-scaled() {
  ItemLevel >= 65 { Show; SetFontSize 13 }
  ItemLevel >= 70 { Show; SetFontSize 14 }
  ItemLevel >= 75 { Show; SetFontSize 15 }
}

Class "Bows" {
  Show
  @ilvl-scaled()
}

Class "Maces" {
  Show
  @ilvl-scaled()
}
```

Macros can have arguments:

```
@hide-under(@ilvl) {
  ItemLevel < @ilvl {
    Hide
  }
}

Class Shield {
  @hide-under(25)
}
```

Finally, you can write comments with `#`. Anything after `#` and the `#` will be ignored.

## Prerequisites

Ruby >= 2 is necessary to install the command line tool. If you have that, just run `gem install poe-css` and then `poe-css <input file>`.

## Running the tests

`bundle exec rake`

## Built With

* [Parslet](https://kschiess.github.io/parslet/) - Ruby PEG Parser

## Contributing

Please read
[CONTRIBUTING.md](https://github.com/aquach/poe-css/blob/master/CONTRIBUTING.md)
for details on our code of conduct, and the process for submitting pull
  requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available,
see the [tags on this repository](https://github.com/aquach/poe-css/tags).

## Authors

* **Alex Quach** - *Initial work* - [aquach](https://github.com/aquach)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details
