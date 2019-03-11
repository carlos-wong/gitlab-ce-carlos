# frozen_string_literal: true

module FinderMethods
  # rubocop: disable CodeReuse/ActiveRecord
  def find_by!(*args)
    raise_not_found_unless_authorized execute.reorder(nil).find_by!(*args)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  # rubocop: disable CodeReuse/ActiveRecord
  def find_by(*args)
    if_authorized execute.reorder(nil).find_by(*args)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def find(*args)
    raise_not_found_unless_authorized model.find(*args)
  end

  private

  def raise_not_found_unless_authorized(result)
    result = if_authorized(result)

    raise ActiveRecord::RecordNotFound.new("Couldn't find #{model}") unless result

    result
  end

  def if_authorized(result)
    # Return the result if the finder does not perform authorization checks.
    # this is currently the case in the `MilestoneFinder`
    return result unless respond_to?(:current_user)

    if can_read_object?(result)
      result
    else
      nil
    end
  end

  def can_read_object?(object)
    # When there's no policy, we'll allow the read, this is for example the case
    # for Todos
    return true unless DeclarativePolicy.has_policy?(object)

    model_name = object&.model_name || model.model_name

    Ability.allowed?(current_user, :"read_#{model_name.singular}", object)
  end

  # This fetches the model from the `ActiveRecord::Relation` but does not
  # actually execute the query.
  def model
    execute.model
  end
end
