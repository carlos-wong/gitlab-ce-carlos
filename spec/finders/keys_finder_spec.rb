# frozen_string_literal: true

require 'spec_helper'

describe KeysFinder do
  subject { described_class.new(params).execute }

  let(:user) { create(:user) }
  let(:params) { {} }

  let!(:key_1) do
    create(:personal_key,
      last_used_at: 7.days.ago,
      user: user,
      key: 'ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIEAiPWx6WM4lhHNedGfBpPJNPpZ7yKu+dnn1SJejgt1016k6YjzGGphH2TUxwKzxcKDKKezwkpfnxPkSMkuEspGRt/aZZ9wa++Oi7Qkr8prgHc4soW6NUlfDzpvZK2H5E7eQaSeP3SAwGmQKUFHCddNaP0L+hM7zhFNzjFvpaMgJw0=',
      fingerprint: 'ba:81:59:68:d7:6c:cd:02:02:bf:6a:9b:55:4e:af:d1',
      fingerprint_sha256: 'nUhzNyftwADy8AH3wFY31tAKs7HufskYTte2aXo/lCg')
  end

  let!(:key_2) { create(:personal_key, last_used_at: nil, user: user) }
  let!(:key_3) { create(:personal_key, last_used_at: 2.days.ago) }

  context 'key_type' do
    let!(:deploy_key) { create(:deploy_key) }

    context 'when `key_type` is `ssh`' do
      before do
        params[:key_type] = 'ssh'
      end

      it 'returns only SSH keys' do
        expect(subject).to contain_exactly(key_1, key_2, key_3)
      end
    end

    context 'when `key_type` is not specified' do
      it 'returns all types of keys' do
        expect(subject).to contain_exactly(key_1, key_2, key_3, deploy_key)
      end
    end
  end

  context 'fingerprint' do
    context 'with invalid fingerprint' do
      context 'with invalid MD5 fingerprint' do
        before do
          params[:fingerprint] = '11:11:11:11'
        end

        it 'raises InvalidFingerprint' do
          expect { subject }.to raise_error(KeysFinder::InvalidFingerprint)
        end
      end

      context 'with invalid SHA fingerprint' do
        before do
          params[:fingerprint] = 'nUhzNyftwAAKs7HufskYTte2g'
        end

        it 'raises InvalidFingerprint' do
          expect { subject }.to raise_error(KeysFinder::InvalidFingerprint)
        end
      end
    end

    context 'with valid fingerprints' do
      let!(:deploy_key) do
        create(:deploy_key,
          user: user,
          key: 'ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIEAiPWx6WM4lhHNedGfBpPJNPpZ7yKu+dnn1SJejgt1017k6YjzGGphH2TUxwKzxcKDKKezwkpfnxPkSMkuEspGRt/aZZ9wa++Oi7Qkr8prgHc4soW6NUlfDzpvZK2H5E7eQaSeP3SAwGmQKUFHCddNaP0L+hM7zhFNzjFvpaMgJw0=',
          fingerprint: '8a:4a:12:92:0b:50:47:02:d4:5a:8e:a9:44:4e:08:b4',
          fingerprint_sha256: '4DPHOVNh53i9dHb5PpY2vjfyf5qniTx1/pBFPoZLDdk')
      end

      context 'personal key with valid MD5 params' do
        context 'with an existent fingerprint' do
          before do
            params[:fingerprint] = 'ba:81:59:68:d7:6c:cd:02:02:bf:6a:9b:55:4e:af:d1'
          end

          it 'returns the key' do
            expect(subject).to eq(key_1)
            expect(subject.user).to eq(user)
          end
        end

        context 'deploy key with an existent fingerprint' do
          before do
            params[:fingerprint] = '8a:4a:12:92:0b:50:47:02:d4:5a:8e:a9:44:4e:08:b4'
          end

          it 'returns the key' do
            expect(subject).to eq(deploy_key)
            expect(subject.user).to eq(user)
          end
        end

        context 'with a non-existent fingerprint' do
          before do
            params[:fingerprint] = 'bb:81:59:68:d7:6c:cd:02:02:bf:6a:9b:55:4e:af:d2'
          end

          it 'returns nil' do
            expect(subject).to be_nil
          end
        end
      end

      context 'personal key with valid SHA256 params' do
        context 'with an existent fingerprint' do
          before do
            params[:fingerprint] = 'SHA256:nUhzNyftwADy8AH3wFY31tAKs7HufskYTte2aXo/lCg'
          end

          it 'returns key' do
            expect(subject).to eq(key_1)
            expect(subject.user).to eq(user)
          end
        end

        context 'deploy key with an existent fingerprint' do
          before do
            params[:fingerprint] = 'SHA256:4DPHOVNh53i9dHb5PpY2vjfyf5qniTx1/pBFPoZLDdk'
          end

          it 'returns key' do
            expect(subject).to eq(deploy_key)
            expect(subject.user).to eq(user)
          end
        end

        context 'with a non-existent fingerprint' do
          before do
            params[:fingerprint] = 'SHA256:xTjuFqftwADy8AH3wFY31tAKs7HufskYTte2aXi/mNp'
          end

          it 'returns nil' do
            expect(subject).to be_nil
          end
        end
      end
    end
  end

  context 'user' do
    context 'without user' do
      it 'contains ssh_keys of all users in the system' do
        expect(subject).to contain_exactly(key_1, key_2, key_3)
      end
    end

    context 'with user' do
      before do
        params[:users] = user
      end

      it 'contains ssh_keys of only the specified users' do
        expect(subject).to contain_exactly(key_1, key_2)
      end
    end
  end

  context 'sort order' do
    it 'sorts in last_used_at_desc order' do
      expect(subject).to eq([key_3, key_1, key_2])
    end
  end
end
