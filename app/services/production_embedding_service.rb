class ProductionEmbeddingService
  def initialize(batch_size: 10, delay_seconds: 1)
    @batch_size = batch_size
    @delay_seconds = delay_seconds
    @processed_count = 0
    @success_count = 0
    @error_count = 0
  end

  def generate_embeddings_for_published_facts
    puts "Starting embedding generation for published facts..."
    puts "Batch size: #{@batch_size}, Delay: #{@delay_seconds}s between batches"
    puts "=" * 60

    # Find all published facts without embeddings
    facts_without_embeddings = Claim.published_facts_without_embeddings

    total_facts = facts_without_embeddings.count
    puts "Found #{total_facts} published facts without embeddings"

    if total_facts == 0
      puts "✅ All published facts already have embeddings!"
      return
    end

    # Process in batches
    facts_without_embeddings.find_in_batches(batch_size: @batch_size) do |batch|
      process_batch(batch)
      sleep(@delay_seconds) unless batch.last == facts_without_embeddings.last
    end

    print_summary
  end

  def generate_embedding_for_specific_fact(claim_id)
    claim = Claim.find(claim_id)

    unless claim.fact? && claim.published?
      puts "❌ Claim #{claim_id} is not a published fact"
      return false
    end

    if claim.content_embedding.present?
      puts "ℹ️  Claim #{claim_id} already has embedding"
      return true
    end

    puts "Generating embedding for fact #{claim_id}: #{claim.content[0..50]}..."

    begin
      embedding_service = ClaimEmbeddingService.new(claim.content)
      embedding = embedding_service.generate_embedding
      normalized_hash = embedding_service.generate_hash

      if embedding.present? && normalized_hash.present?
        claim.update_columns(
          content_embedding: embedding,
          normalized_content_hash: normalized_hash
        )
        puts "✅ Successfully generated embedding for fact #{claim_id}"
        return true
      else
        puts "❌ Failed to generate embedding for fact #{claim_id}"
        return false
      end
    rescue => e
      puts "❌ Error generating embedding for fact #{claim_id}: #{e.message}"
      return false
    end
  end

  def check_embedding_status
    total_published_facts = Claim.where(published: true, fact: true).count
    facts_with_embeddings = Claim.where(published: true, fact: true).where.not(content_embedding: nil).count
    facts_without_embeddings = Claim.published_facts_without_embeddings.count

    puts "📊 Embedding Status Report"
    puts "=" * 40
    puts "Total published facts: #{total_published_facts}"
    puts "Facts with embeddings: #{facts_with_embeddings}"
    puts "Facts without embeddings: #{facts_without_embeddings}"

    if total_published_facts > 0
      percentage = (facts_with_embeddings.to_f / total_published_facts * 100).round(1)
      puts "Progress: #{percentage}%"
    end

    if facts_without_embeddings > 0
      puts "\n📋 Facts without embeddings:"
      Claim.published_facts_without_embeddings.limit(10).each do |claim|
        puts "  - ID: #{claim.id}, Content: #{claim.content[0..50]}..."
      end
      if facts_without_embeddings > 10
        puts "  ... and #{facts_without_embeddings - 10} more"
      end
    end
  end

  private

  def process_batch(batch)
    puts "\n🔄 Processing batch of #{batch.size} facts..."

    batch.each do |claim|
      @processed_count += 1

      begin
        embedding_service = ClaimEmbeddingService.new(claim.content)
        embedding = embedding_service.generate_embedding
        normalized_hash = embedding_service.generate_hash

        if embedding.present? && normalized_hash.present?
          claim.update_columns(
            content_embedding: embedding,
            normalized_content_hash: normalized_hash
          )
          @success_count += 1
          puts "  ✅ Fact #{claim.id}: #{claim.content[0..50]}..."
        else
          @error_count += 1
          puts "  ❌ Fact #{claim.id}: Failed to generate embedding"
        end
      rescue => e
        @error_count += 1
        puts "  ❌ Fact #{claim.id}: Error - #{e.message}"
      end
    end

    puts "  📈 Progress: #{@processed_count} processed, #{@success_count} successful, #{@error_count} errors"
  end

  def print_summary
    puts "\n" + "=" * 60
    puts "🎉 EMBEDDING GENERATION COMPLETED"
    puts "=" * 60
    puts "Total processed: #{@processed_count}"
    puts "Successful: #{@success_count}"
    puts "Errors: #{@error_count}"
    puts "Success rate: #{@success_count > 0 ? (@success_count.to_f / @processed_count * 100).round(1) : 0}%"

    if @error_count > 0
      puts "\n⚠️  Some facts failed to generate embeddings. Check the logs above."
    else
      puts "\n✅ All facts processed successfully!"
    end
  end
end
