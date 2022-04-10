class String
  # Is this too little to suggest for addition to the stdlib?
  def compact
    self.strip.gsub(/\s+/, " ")
  end
end
