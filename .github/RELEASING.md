# Releasing BlockBags

## CurseForge setup

Link the public GitHub repository in the project's Source page. Select
**The packager will package any new tagged commits it sees when code is pushed**.
The repository webhook must point to the project's CurseForge packaging endpoint
and subscribe to push events.

The webhook token belongs in GitHub's webhook settings. Do not put it in the
repository, this guide, or GitHub Actions variables.

The root `.pkgmeta` keeps the addon folder named `BlockBags`, excludes development
files and uses `CHANGELOG.md` as a Markdown changelog. The package includes the
addon files, key bindings, README, changelog, license and third-party notices.

## Prepare a version

1. Set the matching base version in `BlockBags.toc` and `Core.lua`, for example `0.9.0`.
2. Add the release notes to `CHANGELOG.md` in English.
3. Run the offline validation for the supported client languages and build the package:

   ```sh
   python -m pip install -r tests/requirements.txt
   python tests/validate.py ptBR
   python tests/validate.py enUS
   python tests/validate.py esES
   python tests/validate.py frFR
   python tools/package.py
   ```

4. Complete the relevant in-game checks in `TESTING.md` before marking a build
   stable.
5. Commit the changes and push `main`. Wait for the validation workflow to pass.

## Publish from GitHub Desktop

1. Open **History** and right-click the tested release commit.
2. Choose **Create Tag...** and enter a new version tag.
3. Push the tag to GitHub. Desktop shows an arrow next to tags that have not been
   pushed yet.

Use the `v` prefix so the same tag triggers the existing GitHub release workflow:

| Tag example | CurseForge file type | GitHub release |
| --- | --- | --- |
| `v0.9.0-alpha1` | Alpha | Pre-release |
| `v0.9.0-beta1` | Beta | Pre-release |
| `v0.9.0` | Release | Stable |

The version without the `v` prefix and alpha/beta suffix must match the TOC base
version. Use a new tag for each build, such as `v0.9.0-beta2` for another preview.
Use an `alpha` or `beta` suffix for previews; the CurseForge packager does not
classify `rc` as a preview suffix.

The webhook asks CurseForge to build and upload its package. Separately, the
GitHub release workflow runs validation, builds the local ZIP and attaches it to
a GitHub release. If the release was created manually, the workflow uploads the
ZIP to that existing release and preserves its title, notes and release label.
Rerunning the workflow replaces an asset with the same filename. There is no
need to upload the ZIP manually to CurseForge when automatic packaging succeeds.

Workflow fixes apply to new tags containing the fix. Rerunning a failed run for
an older tag uses that tag's original workflow, so it will not pick up a later
fix on main. Keep published version tags unchanged; the existing CurseForge
package is unaffected by a failed GitHub release step.

## Check the result

- Check the webhook's **Recent Deliveries** in the GitHub repository settings.
- Check **Actions** for validation and GitHub release results.
- Check the CurseForge project's **Files** page for the new package and its file
  type.
- Open the ZIP and confirm `BlockBags/BlockBags.toc` exists. Development folders,
  workflows and local character data should not be in it.

CurseForge project approval and file review still apply. Packaging through the
webhook runs independently of GitHub Actions and does not wait for its checks,
so only tag a commit after its validation has passed.

References:

- [CurseForge automatic packaging](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging)
- [CurseForge PackageMeta format](https://support.curseforge.com/support/solutions/articles/9000197952-preparing-the-packagemeta-file)
- [Managing tags in GitHub Desktop](https://docs.github.com/en/desktop/managing-commits/managing-tags-in-github-desktop)
