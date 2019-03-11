# frozen_string_literal: true

shared_examples 'diff file base entity' do
  it 'exposes essential attributes' do
    expect(subject).to include(:content_sha, :submodule, :submodule_link,
                               :submodule_tree_url, :old_path_html,
                               :new_path_html, :blob, :can_modify_blob,
                               :file_hash, :file_path, :old_path, :new_path,
                               :viewer, :diff_refs, :stored_externally,
                               :external_storage, :renamed_file, :deleted_file,
                               :a_mode, :b_mode, :new_file)
  end

  # Converted diff files from GitHub import does not contain blob file
  # and content sha.
  context 'when diff file does not have a blob and content sha' do
    it 'exposes some attributes as nil' do
      allow(diff_file).to receive(:content_sha).and_return(nil)
      allow(diff_file).to receive(:blob).and_return(nil)

      expect(subject[:context_lines_path]).to be_nil
      expect(subject[:view_path]).to be_nil
      expect(subject[:highlighted_diff_lines]).to be_nil
      expect(subject[:can_modify_blob]).to be_nil
    end
  end
end

shared_examples 'diff file entity' do
  it_behaves_like 'diff file base entity'

  it 'exposes correct attributes' do
    expect(subject).to include(:added_lines, :removed_lines,
                               :context_lines_path, :highlighted_diff_lines,
                               :parallel_diff_lines)
  end

  it 'includes viewer' do
    expect(subject[:viewer].with_indifferent_access)
        .to match_schema('entities/diff_viewer')
  end
end

shared_examples 'diff file discussion entity' do
  it_behaves_like 'diff file base entity'
end
