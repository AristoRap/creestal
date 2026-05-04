require "./base_resource"

module Creestal
  module Scaffold
    ecr_resource Index, "index.md", "../templates/pages/index.ecr"
    ecr_resource About, "about.md", "../templates/pages/about.ecr"
    ecr_resource Docs, "docs.md", "../templates/pages/docs.ecr"
    ecr_resource Changelog, "changelog.md", "../templates/pages/changelog.ecr"
    ecr_resource FirstPost, "blog/first-post.md", "../templates/pages/blog/first-post.ecr"

    resource_group Pages, Index, About, Docs, Changelog, FirstPost
  end
end
