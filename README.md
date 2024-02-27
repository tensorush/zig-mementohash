## :lizard: :memo: **zig mementohash**

[![CI][ci-shield]][ci-url]
[![CD][cd-shield]][cd-url]
[![DC][dc-shield]][dc-url]
[![LC][lc-shield]][lc-url]

### Zig port of the [MementoHash consistent hash algorithm](https://github.com/slashdotted/cpp-consistent-hashing-algorithms) created by [Massimo Coluzzi](https://github.com/massimo-coluzzi-supsi) and [Amos Brocco](https://github.com/slashdotted).

#### :rocket: Usage

1. Add `mementohash` as a dependency in your `build.zig.zon`.

    <details>

    <summary><code>build.zig.zon</code> example</summary>

    ```zig
    .{
        .name = "<name_of_your_package>",
        .version = "<version_of_your_package>",
        .dependencies = .{
            .mementohash = .{
                .url = "https://github.com/tensorush/zig-mementohash/archive/<git_tag_or_commit_hash>.tar.gz",
                .hash = "<package_hash>",
            },
        },
    }
    ```

    Set `<package_hash>` to `12200000000000000000000000000000000000000000000000000000000000000000`, and Zig will provide the correct found value in an error message.

    </details>

2. Add `mementohash` as a module in your `build.zig`.

    <details>

    <summary><code>build.zig</code> example</summary>

    ```zig
    const mementohash = b.dependency("mementohash", .{});
    exe.addModule("MementoHash", mementohash.module("MementoHash"));
    ```

    </details>

#### :bar_chart: Benchmarks

```sh
$ zig build bench
Elapsed time: 151.562ms
Load balance: 8.82
Number of misplaced keys after removal: 0.00%
Number of misplaced keys after restoring: 0.00%
```

<!-- MARKDOWN LINKS -->

[ci-shield]: https://img.shields.io/github/actions/workflow/status/tensorush/zig-mementohash/ci.yaml?branch=main&style=for-the-badge&logo=github&label=CI&labelColor=black
[ci-url]: https://github.com/tensorush/zig-mementohash/blob/main/.github/workflows/ci.yaml
[cd-shield]: https://img.shields.io/github/actions/workflow/status/tensorush/zig-mementohash/cd.yaml?branch=main&style=for-the-badge&logo=github&label=CD&labelColor=black
[cd-url]: https://github.com/tensorush/zig-mementohash/blob/main/.github/workflows/cd.yaml
[dc-shield]: https://img.shields.io/badge/click-F6A516?style=for-the-badge&logo=zig&logoColor=F6A516&label=docs&labelColor=black
[dc-url]: https://tensorush.github.io/zig-mementohash
[lc-shield]: https://img.shields.io/github/license/tensorush/zig-mementohash.svg?style=for-the-badge&labelColor=black
[lc-url]: https://github.com/tensorush/zig-mementohash/blob/main/LICENSE.md
