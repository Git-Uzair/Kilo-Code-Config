# Third-party skills vendored into skills/<name>/ by scripts/sync-skills.ps1.
# Edit this file, run the script, review `git diff -- skills`, commit.
# Never hand-edit a vendored folder: the next sync overwrites it.
# Drop a skill: delete its line here, then `git rm -r skills/<name>`.
# Local skills (codebase-map) are not listed; the script never touches them.
@{
    Sources      = @(
        @{
            Repo         = 'https://github.com/mattpocock/skills'
            Commit       = 'e47c149e9489bccd6acb41a1fb420ed68a5067e1'
            LicenseFiles = @('LICENSE')                        # MIT
            Skills       = @{
                'tdd'                = 'skills/engineering/tdd'                 # replaces superpowers test-driven-development
                'codebase-design'    = 'skills/engineering/codebase-design'     # hard dependency of tdd
                'diagnosing-bugs'    = 'skills/engineering/diagnosing-bugs'     # replaces systematic-debugging
                'domain-modeling'    = 'skills/engineering/domain-modeling'     # hard dependency of grill-with-docs
                'grill-with-docs'    = 'skills/engineering/grill-with-docs'     # attended design interview
                'retro'              = 'skills/engineering/retro'               # post-run review of the harness
                'grilling'           = 'skills/productivity/grilling'           # hard dependency of grill-with-docs
                'writing-for-agents' = 'skills/productivity/writing-for-agents' # replaces skill-creator; hard dependency of retro
            }
        },
        @{
            Repo         = 'https://github.com/JuliusBrussee/caveman'
            Commit       = '6571943370f7c9d4de1946481177ee7b306cd8e8'
            LicenseFiles = @('LICENSE', 'NOTICE', 'LICENSE-MIT') # Apache-2.0; NOTICE and the pre-3.0 MIT text must travel
            Skills       = @{
                'caveman'   = 'skills/caveman'   # terse voice; ponytail says "pair with Caveman"
                'ultracave' = 'skills/ultracave' # hard dependency of caveman (/caveman ultra)
                'megacave'  = 'skills/megacave'  # hard dependency of caveman (/caveman wenyan)
            }
        },
        @{
            Repo         = 'https://github.com/DietrichGebert/ponytail'
            Commit       = 'e3ba2aa6f1e6f0bc4d69eb09c9f0d0a93af56156'
            LicenseFiles = @('LICENSE')                        # MIT
            Skills       = @{
                'ponytail'        = 'skills/ponytail'
                'ponytail-review' = 'skills/ponytail-review'
            }
        },
        @{
            Repo         = 'https://github.com/anthropics/skills'
            Commit       = '33375500bcea98d610eb30ce10ac4e59b89c390d'
            LicenseFiles = @()                                 # Apache-2.0 LICENSE.txt ships inside the folder
            Skills       = @{
                'frontend-design' = 'skills/frontend-design'
            }
        }
    )

    # References the closure check accepts without shipping the target.
    # Every entry needs its reason.
    Acknowledged = @{
        'tdd'          = @('code-review')      # "see the code-review skill" about refactoring; the review stage here is @verifier / @verifier-lite
        'caveman'      = @('caveman-compress') # named only as an exemption from the voice rules
        'ultracave'    = @('caveman-compress') # same exemption clause
        'megacave'     = @('caveman-compress') # same exemption clause
        'codebase-map' = @('triage')           # kopipasta's "triage" mode in a JSON example, not a skill
    }
}
