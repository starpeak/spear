module Spear
  module Model
    module ActiveRecord
      module DeleteFlag
        def self.included(base)
          base.extend ActMethods
        end

        module ActMethods
          def spear_delete_flag
            unless has_spear_delete_flag?
              include InstanceMethods
              class << self
                alias_method_chain :find, :spear_delete_flag
                alias_method_chain :count, :spear_delete_flag
                # Some Helpers
                alias_method :count_with_deleted, :count_without_spear_delete_flag
                alias_method :find_with_deleted, :find_without_spear_delete_flag
              end
              alias_method_chain :destroy, :spear_delete_flag
            end
          end

          def has_spear_delete_flag?
            self.included_modules.include?(InstanceMethods)
          end
        end

        module InstanceMethods
          def self.included(base) # :nodoc:
            base.extend ClassMethods
          end

          module ClassMethods
            def find_with_spear_delete_flag(*args)
              options = args.extract_options!#args.last.is_a?(Hash) ? args.last : {}
              if options[:conditions].nil?
                options[:conditions] = "#{self.quoted_table_name}.`deleted_at` IS NULL"
              else
                options[:conditions] = sanitize_sql(options[:conditions]) +
                  " AND #{self.quoted_table_name}.`deleted_at` IS NULL"
              end
              find_without_spear_delete_flag(*(args + [options]))
            end

            def count_with_spear_delete_flag(*args)
              options = args.is_a?(Hash) ? args : {}
              if options[:conditions].nil?
                options[:conditions] = "#{self.quoted_table_name}.`deleted_at` IS NULL"
              else
                options[:conditions] = sanitize_sql(options[:conditions]) +
                  " AND #{self.quoted_table_name}.`deleted_at` IS NULL"
              end
              count_without_spear_delete_flag(*([options]))
            end

            def undestroy(id)
              connection.update(
                  "UPDATE #{self.quoted_table_name} " +
                  "SET `deleted_at` = NULL " +
                  "WHERE #{connection.quote_column_name(self.primary_key)} = #{id}",
                  "#{self.name} Undestroy"
                )
              self.find(id)
            end
          end
       
          def undestroy
            connection.update(
                  "UPDATE #{self.class.quoted_table_name} " +
                  "SET `deleted_at` = NULL " +
                  "WHERE #{connection.quote_column_name(self.class.primary_key)} = #{self.id}",
                  "#{self.class.name} Undestroy"
                )

            self.class.find(self.id)
          end

          def destroy_with_spear_delete_flag
            return false if callback(:before_destroy) == false
            unless new_record?
              #self.update_attribute(:is_deleted, true)
              connection.delete(
                    "UPDATE #{self.class.quoted_table_name} " +
                    "SET `deleted_at` = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' " +
                    "WHERE #{connection.quote_column_name(self.class.primary_key)} = #{quoted_id}",
                    "#{self.class.name} Destroy"
                  )
            end
            result = freeze
            callback(:after_destroy)
            result
          end


        end
      end
    end
  end
end
