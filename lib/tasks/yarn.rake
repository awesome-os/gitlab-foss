# frozen_string_literal: true

namespace :yarn do
  desc 'Ensure Yarn is installed'
  task :available do
    unless system('yarn --version', out: File::NULL)
      warn(
        Rainbow('Error: Yarn executable was not detected in the system.').red,
        Rainbow('Download Yarn at https://yarnpkg.com/getting-started/install').green
      )
      abort
    end
  end

  desc 'Install Node dependencies with Yarn'
  task install: ['yarn:available'] do
    # Yarn 4 ignores NODE_ENV, so production installs skip devDependencies with `focus`, as Yarn 1 did.
    command = ENV['NODE_ENV'] == 'production' ? 'yarn workspaces focus --production' : 'yarn install --immutable'

    abort Rainbow('Error: Unable to install node modules.').red unless system(command)
  end

  desc 'Remove Node dependencies'
  task :clobber do
    warn Rainbow('Purging ./node_modules directory').red
    FileUtils.rm_rf 'node_modules'
  end
end

desc 'Install Node dependencies with Yarn'
task yarn: ['yarn:install']
