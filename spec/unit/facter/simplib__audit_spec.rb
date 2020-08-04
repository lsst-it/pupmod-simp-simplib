require 'spec_helper'

describe 'simplib__auditd' do
  before :each  do
    Facter.clear

    Facter.stubs(:value).with(:kernel).returns('Linux')
    Facter::Core::Execution.stubs(:exec).with('uname -s').returns('Linux')

    Facter::Util::Resolution.stubs(:which).with('auditctl').returns('/sbin/auditctl')
  end

  context 'with auditctl not present' do
    it do
      Facter::Util::Resolution.stubs(:which).with('auditctl').returns(nil)

      expect(Facter.fact('simplib__auditd').value).to be_nil
    end
  end

  context 'with audit disabled in the kernel' do
    it do
      Facter::Core::Execution.expects(:exec).with('/sbin/auditctl -s').returns("\n")
      Facter::Core::Execution.expects(:exec).with('/sbin/auditctl -v').returns("\n")
      Facter.stubs(:value).with('cmdline').returns({ 'audit' => '0'})

      expect(Facter.fact('simplib__auditd').value).to eq(
        {
          'enabled'          => false,
          'kernel_enforcing' => false
        }
      )
    end
  end

  context 'with auditd disabled and audit enabled in the kernel' do
    it do
      Facter::Core::Execution.expects(:exec).with('/sbin/auditctl -v').returns("1.2.3\n")
      Facter::Core::Execution.expects(:exec).with('/sbin/auditctl -s').returns("\n")
      Facter.stubs(:value).with('cmdline').returns({ 'audit' => '1'})

      expect(Facter.fact('simplib__auditd').value).to eq(
        {
          'enabled'          => false,
          'kernel_enforcing' => true,
          'version'          => '1.2.3'
        }
      )
    end
  end

  context 'with a properly functioning auditd' do
    before(:each) do
      Facter::Core::Execution.expects(:exec).with('/sbin/auditctl -v').returns("1.2.3\n")
      Facter::Core::Execution.expects(:exec).with('/sbin/auditctl -s')
        .returns( <<~AUDITCTL_S
                 enabled 1
                 failure 1
                 pid 1337
                 rate_limit 0
                 backlog_limit 64
                 lost 0
                 backlog 0
                 backlog_wait_time 60000
                 loginuid_immutable 0 unlocked
                 AUDITCTL_S
                )
    end

    let(:simplib__auditd_value) do
      {
        'enabled'            => true,
        'kernel_enforcing'   => true,
        'version'            => '1.2.3',
        'failure'            => 1,
        'pid'                => 1337,
        'rate_limit'         => 0,
        'backlog_limit'      => 64,
        'lost'               => 0,
        'backlog'            => 0,
        'backlog_wait_time'  => 60000,
        'loginuid_immutable' => '0 unlocked'
      }
    end

    context 'with audit explicitly enabled in the kernel' do
      it do
        Facter.stubs(:value).with('cmdline').returns({ 'audit' => '1'})
        expect(Facter.fact('simplib__auditd').value).to eq(simplib__auditd_value)
      end
    end

    context 'with audit implicitly enabled in the kernel' do
      it do
        Facter.stubs(:value).with('cmdline').returns({})
        expect(Facter.fact('simplib__auditd').value).to eq(simplib__auditd_value)
      end
    end
  end
end
