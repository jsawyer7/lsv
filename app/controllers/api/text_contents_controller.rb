class Api::TextContentsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_request

  def create_next
    # Parse JSON from request body
    request_data = JSON.parse(request.body.read) rescue params.to_unsafe_h
    
    source_name = request_data['source_name'] || request_data[:source_name]
    current = request_data['current'] || request_data[:current] || {}
    
    book_code = current['book_code'] || current[:book_code]
    chapter = current['chapter'] || current[:chapter]
    verse = current['verse'] || current[:verse]

    unless source_name && book_code && chapter && verse
      render json: {
        status: 'error',
        error: 'Missing required parameters: source_name, current.book_code, current.chapter, current.verse',
        received: request_data
      }, status: :bad_request
      return
    end

    service = TextContentCreationService.new(
      source_name: source_name,
      current_book_code: book_code,
      current_chapter: chapter.to_i,
      current_verse: verse.to_i
    )

    result = service.create_next

    if result[:status] == 'error'
      render json: result, status: :unprocessable_entity
    else
      render json: result, status: :ok
    end
  end

  def ai_validate_structure
    params_hash = params.permit(:source_name, current: [:book_code, :chapter, :verse], 
                                 next_created: [:book_code, :chapter, :verse]).to_h.symbolize_keys
    
    source_name = params_hash[:source_name]
    current = params_hash[:current] || {}
    next_created = params_hash[:next_created] || {}

    book_code = current[:book_code] || params[:book_code]
    chapter = current[:chapter] || params[:chapter]
    verse = current[:verse] || params[:verse]

    unless source_name && book_code && chapter && verse
      render json: {
        status: 'error',
        error: 'Missing required parameters: source_name, current.book_code, current.chapter, current.verse'
      }, status: :bad_request
      return
    end

    validator = TextContentAiValidatorService.new(
      source_name: source_name,
      current_book_code: book_code,
      current_chapter: chapter.to_i,
      current_verse: verse.to_i
    )

    result = validator.validate_structure

    if result[:status] == 'error'
      render json: result, status: :unprocessable_entity
    else
      render json: result, status: :ok
    end
  end

  private

  def authenticate_api_request
    # For now, allow all requests. You can add API key authentication later
    # api_key = request.headers['X-API-Key']
    # unless api_key == Rails.application.secrets.dig(:api, :key)
    #   render json: { error: 'Unauthorized' }, status: :unauthorized
    # end
  end
end

