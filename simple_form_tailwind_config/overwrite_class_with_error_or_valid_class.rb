module SimpleForm::OverwriteClassWithErrorOrValidClass
  def set_input_classes(wrapper_options)
    wrapper_options = wrapper_options.dup
    error_class     = wrapper_options.delete(:error_class)
    valid_class     = wrapper_options.delete(:valid_class)

    if error_class.present? && has_errors?
      wrapper_options[:class] = error_class
    end

    if valid_class.present? && valid?
      wrapper_options[:class] = valid_class
    end

    wrapper_options
  end
end

module SimpleForm
  module Inputs
    class Base
      prepend SimpleForm::OverwriteClassWithErrorOrValidClass
    end
  end
end
