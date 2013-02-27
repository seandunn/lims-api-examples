require 'helper/constant'

module Lims::Api::Examples
  module PostExtractionTubeRacking

    include Constant
    include Constant::DnaRnaManualExtraction

    private

    def post_extraction_tube_racking_workflow
      post_extraction_tube_racking_workflow_for("RNA")
      post_extraction_tube_racking_workflow_for("DNA")
    end

    def post_extraction_tube_racking_workflow_for(type)
      # =================================== 
      API::new_stage("#{type} post extraction tube racking. Create new tubes. Add them in the order.
Transfer #{type} extracted tubes into 2D tubes. Then rack the 2D tubes in a tube rack.")
      # =================================== 

      # Create new tubes
      tube_2d_uuids = factory(:tube)

      # Add the 2d tubes in the order 
      # and start them
      parameters = parameters_for_adding_resources_in_order(ROLE_NAME => tube_2d_uuids)
      API::put(order_uuid, parameters)

      # Transfer extracted tubes into 2D tubes
      parameters = {:transfer_tubes_to_tubes => {:transfers => [].tap do |a|
        extracted_tube_uuids[type.to_sym].zip(tube_2d_uuids).each do |source_uuid, target_uuid|
          a << {:source_uuid => source_uuid, :target_uuid => target_uuid, :fraction => 1}
        end
      end
      }}
      API::post("actions/transfer_tubes_to_tubes", parameters)

      # Change the status of extracted_tube tubes to unused
      # Change the status of 2d tubes to complete
      parameters = parameters_for_changing_items_status({
        ROLE_EXTRACTED_TUBE => {:uuids => extracted_tube_uuids[type.to_sym], :event => :unuse},
        ROLE_NAME => {:uuids => tube_2d_uuids, :event => :complete}
      })
      API::put(order_uuid, parameters)

      # Create a new tube rack 
      tubes = {}.tap { |h|
        tube_2d_uuids.zip(('A'..'H').map { |r| (1..12).map { |c| "#{r}#{c}" } }.flatten).each { |uuid, location|
          h[location] = uuid
        }}
      parameters = {:tube_rack => {:number_of_columns => 12,
                                   :number_of_rows => 8,
                                   :tubes => tubes}}
      response = API::post("tube_racks", parameters)
      tube_rack_uuid = response["tube_rack"]["uuid"]

      # Add the tube rack in the order and start it
      tube_rack_role = (type == "RNA") ? ROLE_STOCK_RNA : ROLE_STOCK_DNA
      parameters = {:items => {tube_rack_role => {
        tube_rack_uuid => {:event => :start, :batch_uuid => batch_uuid}}}} 
      API::put(order_uuid, parameters)

      # Change the type of the rube rack to complete
      parameters = {:items => {tube_rack_role => {tube_rack_uuid => {:event => :complete}}}}
      API::put(order_uuid, parameters)
    end
  end
end
