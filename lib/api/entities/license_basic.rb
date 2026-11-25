# frozen_string_literal: true

module API
  module Entities
    # Serializes a Gitlab::Git::DeclaredLicense
    class LicenseBasic < Grape::Entity
      expose :key, documentation: { type: 'String', example: 'gpl-3.0', desc: 'Key of the license.' }
      expose :name,
        documentation: { type: 'String', example: 'GNU General Public License v3.0', desc: 'Full name of the license.' }
      expose :nickname, documentation: { type: 'String', example: 'GNU GPLv3', desc: 'Nickname of the license.' }
      expose :url, as: :html_url,
        documentation: {
          type: 'String', example: 'http://choosealicense.com/licenses/gpl-3.0',
          desc: 'URL of the license information page.'
        }

      # This was dropped:
      # https://github.com/github/choosealicense.com/commit/325806b42aa3d5b78e84120327ec877bc936dbdd#diff-66df8f1997786f7052d29010f2cbb4c66391d60d24ca624c356acc0ab986f139
      expose :source_url,
        documentation: { type: 'String', example: nil, desc: 'URL of the license source. Always `null`.' } do |_|
        nil
      end
    end
  end
end
